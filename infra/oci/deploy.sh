#!/usr/bin/env bash
# Run on the dedicated OCI VM after validation. Replaces one process; matches reset.
set -euo pipefail
revision=${1:?Pass the full source commit SHA}
[[ $revision =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid revision' >&2; exit 1; }
exec 9>/tmp/robocon-deploy.lock
flock -n 9 || { echo 'Deployment already running' >&2; exit 1; }
image="robocon-2027-game:$revision"
name=robocon-2027-game
# Limit build CPU/RAM to leave resources for current matches.
DOCKER_BUILDKIT=0 docker build --memory 768m --cpu-period 100000 --cpu-quota 50000 \
  --label "org.opencontainers.image.revision=$revision" -t "$image" .
run_game() {
  docker run -d --name "$1" --restart unless-stopped --env-file /etc/robocon/game.env \
    --memory 3g --pids-limit 256 --cap-drop ALL --security-opt no-new-privileges \
    --log-opt max-size=10m --log-opt max-file=3 -p "127.0.0.1:$2:8080" "$image"
}
healthy() {
  for _ in $(seq 1 30); do
    if docker exec "$1" python3 -c 'import os,urllib.request; r=urllib.request.Request("http://127.0.0.1:8080/health",headers={"X-Arena-Key":os.environ["GAME_ORIGIN_KEY"]}); assert urllib.request.urlopen(r,timeout=2).status==200' 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}
docker rm -f "$name-candidate" 2>/dev/null || true
run_game "$name-candidate" 18080
trap 'docker rm -f "$name-candidate" >/dev/null 2>&1 || true' EXIT
healthy "$name-candidate" || { echo 'Candidate failed health check' >&2; exit 1; }
docker rm -f "$name-candidate"
docker rm -f "$name-previous" 2>/dev/null || true
if docker inspect "$name" >/dev/null 2>&1; then
  docker stop -t 10 "$name"
  docker rename "$name" "$name-previous"
fi
if run_game "$name" 8080 && healthy "$name"; then
  echo "Deployed $revision"
else
  docker rm -f "$name" || true
  docker rename "$name-previous" "$name"
  docker start "$name"
  echo 'Deployment failed; restored previous container' >&2
  exit 1
fi
