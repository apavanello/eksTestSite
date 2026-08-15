#!/usr/bin/env bash
# (Re)registra o node do k3s no target group default do ALB.
# Idempotente: deregistra targets antigos (IP de node anterior) antes de registrar o atual.
set -euo pipefail
: "${KUBECONFIG:?}" "${TG_ARN:?}" "${NODE_PORT:?}" "${ENDPOINT:?}"

export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1

awslocal() { aws --endpoint-url "$ENDPOINT" "$@"; }

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "node IP: $NODE_IP"

awslocal elbv2 describe-target-health --target-group-arn "$TG_ARN" \
  | jq -r '.TargetHealthDescriptions[].Target | "\(.Id) \(.Port)"' \
  | while read -r id port; do
    if [ "$id" != "$NODE_IP" ] || [ "$port" != "$NODE_PORT" ]; then
      echo "deregistrando target antigo: $id:$port"
      awslocal elbv2 deregister-targets --target-group-arn "$TG_ARN" --targets "Id=$id,Port=$port"
    fi
  done

awslocal elbv2 register-targets --target-group-arn "$TG_ARN" --targets "Id=${NODE_IP},Port=${NODE_PORT}"
echo "target registrado: ${NODE_IP}:${NODE_PORT}"
