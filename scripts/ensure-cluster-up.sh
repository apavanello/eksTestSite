#!/usr/bin/env bash
# Pre-flight de apply/destroy/create: garante que o cluster alvo do tfstate
# está acessível antes de o Terraform tentar o refresh.
#
# Saídas:
#   0  = cluster no ar (ou fresh: sem state, sem container — nada a fazer)
#   44 = emulador foi resetado (state obsoleto) — state já foi limpo com backup;
#        o chamador decide se segue (apply) ou aborta (destroy)
#   1  = erro real (container não fica Ready etc.)
set -uo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
K3S=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep '^ministack-eks-' | head -1)
STATE_HAS_CLUSTER=$(cd "$TF_DIR" && terraform state list 2>/dev/null | grep -c '^module\.eks\.aws_eks_cluster')

# redpanda parado = sem Kafka; garante em todos os caminhos
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^redpanda$'; then
  docker inspect redpanda --format '{{.State.Running}}' 2>/dev/null | grep -q true || {
    echo "PRE-FLIGHT: container redpanda estava parado — subindo..."
    docker start redpanda >/dev/null
  }
fi

# caso 1: sem container e sem cluster no state → ambiente fresh, nada a fazer
if [ -z "$K3S" ] && [ "${STATE_HAS_CLUSTER:-0}" -eq 0 ]; then
  exit 0
fi

# caso 2: state aponta para cluster, mas o container não existe → emulador
# foi resetado/reiniciado (apaga estado E container). Limpa o state com backup.
if [ -z "$K3S" ]; then
  echo "PRE-FLIGHT: emulador foi reiniciado (cluster do tfstate não existe mais)."
  echo "Limpando estado obsoleto (backup automático em terraform.tfstate.stale-*)."
  (cd "$TF_DIR" && cp terraform.tfstate "terraform.tfstate.stale-$(date +%Y%m%d-%H%M%S)" 2>/dev/null; \
    rm -f terraform.tfstate terraform.tfstate.backup terraform.tfstate.*.backup)
  ls -1t "$TF_DIR"/terraform.tfstate.stale-* 2>/dev/null | tail -n +4 | xargs -r rm -f
  exit 44
fi

# caso 3: container existe mas está parado → sobe e espera Ready
if ! docker inspect "$K3S" --format '{{.State.Running}}' | grep -q true; then
  echo "PRE-FLIGHT: container $K3S estava parado — subindo..."
  docker start redpanda "$K3S" >/dev/null
fi

echo "PRE-FLIGHT: aguardando node Ready..."
for i in $(seq 1 30); do
  if KUBECONFIG="$TF_DIR/.kube/test-cluster.yaml" kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready "; then
    echo "PRE-FLIGHT: cluster acessível."
    exit 0
  fi
  sleep 2
done

echo "ERRO: node não ficou Ready em 60s — rode 'make k8s' para inspecionar" >&2
exit 1
