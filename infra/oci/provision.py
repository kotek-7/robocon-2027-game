"""Create/reuse this game's isolated A1 VM; never mutate existing applications.

Run with: uv run --with oci==2.187.2 python infra/oci/provision.py --ssh-cidr IP/32
OCI API credentials come from ~/.oci/config; resource IDs go to ignored build/oci.
"""

import argparse
import base64
import ipaddress
import json
import os
from pathlib import Path
import uuid

import oci


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ssh-cidr", required=True)
    parser.add_argument("--key", type=Path, default=Path.home() / ".ssh/robocon_2027_oci.pub")
    args = parser.parse_args()
    ipaddress.IPv4Network(args.ssh_cidr)
    key = args.key.read_text().strip()
    config = oci.config.from_file()
    config["region"] = "ap-osaka-1"
    identity = oci.identity.IdentityClient(config)
    tenancy = config["tenancy"]
    if identity.get_tenancy(tenancy).data.name != "doshisharobot":
        raise SystemExit("Expected the doshisharobot tenancy")
    compute = oci.core.ComputeClient(config)
    network = oci.core.VirtualNetworkClient(config)
    name = "robocon-2027-game"
    state_path = Path("build/oci/resources.json")
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    if state and (state["tenancy"] != tenancy or state["region"] != config["region"]):
        raise SystemExit("Saved resources belong to a different tenancy/region")
    state.update(tenancy=tenancy, region=config["region"])

    def save():
        state_path.write_text(json.dumps(state, indent=2) + "\n")
        os.chmod(state_path, 0o600)

    def listing(fn, **kw):
        return oci.pagination.list_call_get_all_results(fn, **kw).data

    def unique(items):
        matches = [i for i in items if i.display_name == name and i.lifecycle_state not in ("TERMINATED", "TERMINATING")]
        if len(matches) > 1:
            raise RuntimeError("Multiple resources with the game name; inspect before continuing")
        return matches[0] if matches else None

    def remember(kind, obj):
        state[kind] = obj.id
        save()
        print(f"{kind}: {obj.id}", flush=True)
        return obj

    models = oci.core.models
    vcn = unique(listing(network.list_vcns, compartment_id=tenancy))
    if not vcn:
        vcn = network.create_vcn(models.CreateVcnDetails(
            compartment_id=tenancy, display_name=name, cidr_blocks=["10.43.0.0/16"], dns_label="robocon2027",
        )).data
    remember("vcn", vcn)
    gateway = unique(listing(network.list_internet_gateways, compartment_id=tenancy, vcn_id=vcn.id))
    if not gateway:
        gateway = network.create_internet_gateway(models.CreateInternetGatewayDetails(
            compartment_id=tenancy, vcn_id=vcn.id, display_name=name, is_enabled=True,
        )).data
    remember("internet_gateway", gateway)
    route = unique(listing(network.list_route_tables, compartment_id=tenancy, vcn_id=vcn.id))
    if not route:
        route = network.create_route_table(models.CreateRouteTableDetails(
            compartment_id=tenancy, vcn_id=vcn.id, display_name=name,
            route_rules=[models.RouteRule(destination="0.0.0.0/0", destination_type="CIDR_BLOCK", network_entity_id=gateway.id)],
        )).data
    remember("route_table", route)
    security = unique(listing(network.list_security_lists, compartment_id=tenancy, vcn_id=vcn.id))
    if not security:
        security = network.create_security_list(models.CreateSecurityListDetails(
            compartment_id=tenancy, vcn_id=vcn.id, display_name=name,
            ingress_security_rules=[
                models.IngressSecurityRule(protocol="6", source=args.ssh_cidr, tcp_options=models.TcpOptions(destination_port_range=models.PortRange(min=22, max=22))),
                models.IngressSecurityRule(protocol="1", source="0.0.0.0/0", icmp_options=models.IcmpOptions(type=3, code=4)),
            ],
            egress_security_rules=[models.EgressSecurityRule(protocol="all", destination="0.0.0.0/0")],
        )).data
    remember("security_list", security)
    subnet = unique(listing(network.list_subnets, compartment_id=tenancy, vcn_id=vcn.id))
    if not subnet:
        subnet = network.create_subnet(models.CreateSubnetDetails(
            compartment_id=tenancy, vcn_id=vcn.id, display_name=name, dns_label="game",
            cidr_block="10.43.1.0/24", route_table_id=route.id, security_list_ids=[security.id],
            prohibit_public_ip_on_vnic=False,
        )).data
    remember("subnet", subnet)
    subnet = oci.wait_until(network, network.get_subnet(subnet.id), "lifecycle_state", "AVAILABLE", max_wait_seconds=120).data
    instance = unique(listing(compute.list_instances, compartment_id=tenancy))
    if not instance:
        images = listing(compute.list_images, compartment_id=tenancy,
                         operating_system="Canonical Ubuntu", operating_system_version="24.04",
                         shape="VM.Standard.A1.Flex", sort_by="TIMECREATED", sort_order="DESC")
        if not images:
            raise RuntimeError("No Ubuntu 24.04 A1 image")
        ad = identity.list_availability_domains(tenancy).data[0].name
        state.setdefault("launch_retry_token", str(uuid.uuid4()))
        save()
        instance = compute.launch_instance(models.LaunchInstanceDetails(
            compartment_id=tenancy, availability_domain=ad, display_name=name,
            shape="VM.Standard.A1.Flex",
            shape_config=models.LaunchInstanceShapeConfigDetails(ocpus=1, memory_in_gbs=4),
            source_details=models.InstanceSourceViaImageDetails(image_id=images[0].id, boot_volume_size_in_gbs=50),
            create_vnic_details=models.CreateVnicDetails(subnet_id=subnet.id, assign_public_ip=True),
            metadata={"ssh_authorized_keys": key,
                      "user_data": base64.b64encode(Path(__file__).with_name("cloud-init.yaml").read_bytes()).decode()},
        ), opc_retry_token=state["launch_retry_token"]).data
    remember("instance", instance)
    print(f"Instance state: {instance.lifecycle_state}; inspect with OCI before deployment", flush=True)


if __name__ == "__main__":
    main()
