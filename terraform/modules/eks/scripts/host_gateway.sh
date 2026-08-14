#!/usr/bin/env bash
# Resolve o IP do gateway do bridge docker visto de dentro do container k3s
# (equivale ao host.docker.internal resolvido via host-gateway do docker).
set -e

container=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('container',''))")

ip=""
for i in $(seq 1 30); do
  ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.Gateway}} {{end}}' "$container" 2>/dev/null | awk '{print $1}')
  if [ -n "$ip" ]; then
    break
  fi
  sleep 2
done

echo "{\"ip\":\"$ip\"}"
