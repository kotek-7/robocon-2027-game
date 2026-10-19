"""Reuse the tessellation only when its source matches the supplied STEP exactly."""

import hashlib, json, pathlib

root = pathlib.Path(__file__).resolve().parents[1]
ref = pathlib.Path("/home/kotek/dev/gakusei-robocon/web/src")
f = json.loads((ref / "viewport/generated/field.json").read_text())
assert (
    f["sha256"]
    == hashlib.sha256((root / "rulebook/field-2027.step").read_bytes()).hexdigest()
)
(root / "assets/field.json").write_text(json.dumps(f, separators=(",", ":")))
d = json.loads((ref / "engine/model-data.json").read_text())
(root / "assets/spots.json").write_text(json.dumps(d["spots"]))
(root / "assets/routes.json").write_text(json.dumps(d["model"]["field"]))
print("CAD tessellation verified:", f["sha256"])
