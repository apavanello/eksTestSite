#!/usr/bin/env bash
# Aplica os manifests do app com retry — o k3s às vezes perde a corrida
# namespace-x-objeto quando o namespace é criado no mesmo lote.
set -euo pipefail
: "${KUBECONFIG:?}" "${MANIFESTS_DIR:?}"

for i in $(seq 1 5); do
  if kubectl apply -f "$MANIFESTS_DIR"; then
    kubectl -n app rollout status deploy/app-web --timeout=120s
    exit 0
  fi
  echo "apply falhou (tentativa $i), aguardando 3s..." >&2
  sleep 3
done
echo "ERRO: não conseguiu aplicar os manifests do app" >&2
exit 1
