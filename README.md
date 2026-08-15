# eksTestSite

Ambiente de testes **EKS** completo sobre o **MiniStack** (emulador AWS local), 100% gerenciado por Terraform.

O stack simula um cluster EKS real (k3s em container Docker) com add-ons operacionais e serviços AWS emulados, para validar fluxos ponta a ponta sem custo nem conta AWS.

## Stack provisionada

| Camada | O que é | Como acessa |
|---|---|---|
| **EKS** | k3s real (`v1.31.4+k3s1`) em container Docker | `https://localhost:16443` (proxy godoxy) |
| **ArgoCD** | 7 pods (server, controller, dex, redis, repo-server…) | `kubectl -n argocd` / senha inicial via secret |
| **Karpenter** | Controller + NodePool CRD (provisioning emulado) | `kubectl -n karpenter` |
| **API Gateway v2** | REST API + Lambda proxy | `http://<api-id>.execute-api.localhost:4566` |
| **Lambda** | `ministack-api-proxy` (função `/v1/*`) | via APIGW ou ALB |
| **ALB** | Listener + regra `/v1/*` → TG da API | `localhost:4566` com header `Host` |
| **ECR** | `ministack-app-api`, `ministack-app-web`, `ministack-app-worker` | `localhost:4566/<repo>` |
| **Kafka (MSK emulado)** | Cluster `ministack-kafka` (stub) + broker **Redpanda** real | `host.docker.internal:9092` |
| **SNS/SQS** | Tópico `ministack-events` → fila `ministack-queue` (+ `ministack-dlq` com redrive, maxReceiveCount=3) | `localhost:4566` |
| **App de teste** | `app-web` (whoami) do ECR local, 2 réplicas + Service NodePort | via ALB (`/`) ou `kubectl -n app` |
| **KMS** | Chave simétrica `ministack` | `localhost:4566` |
| **SSM** | Parâmetros `/ministack/app/*` | `localhost:4566` |
| **IAM/Networking** | Roles, VPC, subnets, security groups emulados | — |

Endpoint do emulador: `http://localhost:4566` · Conta: `000000000000` · Região: `us-east-1`

## Estrutura

```
eksTestSite/
├── k8s/
│   ├── app/                     # manifests do app de teste (Deployment, Service NodePort)
│   └── argocd/                  # Application do ArgoCD (substituir <REMOTE_URL>)
├── scripts/
│   └── patch-ministack.sh       # patch idempotente do MiniStack (shapes aws v6 no ALB)
├── .github/workflows/ci.yml     # fmt + validate + tflint
└── terraform/
    ├── main.tf            # wiring dos módulos
    ├── terraform.tfvars   # parametrização (cluster, add-ons, ECR, Kafka)
    ├── outputs.tf         # cluster, kubeconfig, apigateway, elb, messaging, kms, ssm…
    ├── .kube/test-cluster.yaml   # kubeconfig gerado (SEMPRE com caminho absoluto)
    └── modules/
        ├── networking/  iam/  kms/  ssm/  messaging/  ecr/  kafka/
        ├── apigateway/  elb/  eks/  addons/  app/
```

## Comandos rápidos

```bash
make setup         # bootstrap: checa pré-requisitos + aplica patch do MiniStack
make plan          # terraform plan
make apply         # terraform apply (recria tudo do zero)
make app-image     # build/push do app de teste (whoami) no ECR local
make fmt           # terraform fmt + validate
make k8s           # kubectl get nodes,pods -A
make argocd        # senha admin do ArgoCD + port-forward da UI (http://localhost:18080)
make karpenter     # logs do controller Karpenter
make test          # validações ponta a ponta (APIGW, ALB, app, SSM, KMS, SNS→SQS, DLQ, Kafka)
make ecr-login     # docker login no ECR local (necessário antes de push de imagens)
make patch-ministack # aplica patch local no MiniStack (idempotente)
make reset         # reinicia o ministack (APAGA o estado emulado; rode make apply depois)
make clean-state   # remove estado local (backup automático; mantém os 3 mais recentes)
```

## Reproduzir do zero

```bash
# 0. pré-requisitos: terraform, aws cli, kubectl, helm, docker, jq e ministack (pipx) instalados
make setup         # valida tudo + patch do MiniStack
make apply         # provisiona o stack (o rollout do app pode avisar — a imagem ainda não existe)
make app-image     # push do whoami para o ECR local (pods sobem em seguida)
make test          # valida ponta a ponta (tudo determinístico)
```

> Após restart do emulador (`make reset`): `make clean-state && make apply && make app-image`.

### Validações manuais

```bash
# APIGW direto (lambda proxy)
curl http://<api-id>.execute-api.localhost:4566/v1/hello
# → {"message": "Hello from MiniStack Lambda", ...}

# ALB → APIGW → Lambda
curl -H "Host: <lb-dns-name>" http://localhost:4566/v1/hello

# SSM
aws --endpoint-url http://localhost:4566 ssm get-parameter \
  --name /ministack/app/config --with-decryption

# KMS — IMPORTANTE: parâmetros blob exigem fileb:// (senão o CLI duplica base64)
CT=$(aws --endpoint-url http://localhost:4566 kms encrypt \
  --key-id <key-id> --plaintext segredo --encryption-context env=test \
  --output json | jq -r .CiphertextBlob)
echo "$CT" | base64 -d > /tmp/ct.bin
aws --endpoint-url http://localhost:4566 kms decrypt \
  --key-id <key-id> --ciphertext-blob fileb:///tmp/ct.bin \
  --encryption-context env=test

# Kafka (topic)
docker exec redpanda rpk topic create meu-topic -p 1
```

> Credenciais falsas: `AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1`

## Peculiaridades do ambiente (IMPORTANTE)

1. **MiniStack não persiste estado.** Reiniciar o emulador (`systemctl --user restart ministack`) apaga TODO o estado AWS emulado **e derruba o container k3s**. Depois de qualquer restart o estado Terraform fica obsoleto (o refresh quebra no `sqs_queue_policy`): `make clean-state && make apply`.
   - Se o apply falhar com *"cannot re-use a name that is still in use"* (release helm parcial): `helm uninstall argocd -n argocd && helm uninstall karpenter -n karpenter` e re-apply.
2. **Kubeconfig só funciona com caminho absoluto** (o shell não persiste env entre comandos). A partir da raiz do repo:
   `export KUBECONFIG=$(pwd)/terraform/.kube/test-cluster.yaml`
3. **KMS via CLI**: parâmetros blob (`--ciphertext-blob`, `--plaintext` em decrypt) precisam de `fileb://` — o aws CLI re-encoda base64 e corrompe o blob.
4. **Karpenter loga erros esperados de emulação** (`InvalidAction: DescribeInstanceTypeOfferings/DescribeSpotPriceHistory`, `Pricing GetProducts` 405). Ausência de `dial tcp`/`no such host` = saudável.
5. **Redpanda** anuncia `172.17.0.1:9092` (não `host.docker.internal`, que não resolve no host). O bootstrap emulado (`host.docker.internal:9092`) resolve para o gateway do bridge dentro dos pods.
6. **Patch local no MiniStack** (sobrevive até reinstalar via pipx): `_parse_conditions` em `ministack/services/alb.py` ganha suporte aos shapes novos do provider aws v6 (`PathPatternConfig`/`HostHeaderConfig`/`SourceIpConfig`) — sem isso, regras do ALB criadas via Terraform ficam com `Values: []`. **Automatizado**: `make patch-ministack` (idempotente; parte do `make setup`).
7. **APIGW id muda a cada apply** → hostname do target do ALB é atualizado automaticamente via output (`module.apigateway.api_hostname`).
8. **CoreDNS NodeHosts** (`host.docker.internal → gateway do bridge`) é re-patchado automaticamente via trigger `cluster_created_at` no módulo addons — necessário sempre que o cluster é recriado.
9. **Karpenter consome a `ministack-queue`** (usada como `interruptionQueue`): mensagens de teste SNS→SQS nela somem em ~20s (poller do controller faz receive+delete). Por isso `make test-sns` e `make test-dlq` usam filas descartáveis dedicadas — determinísticos mesmo com o Karpenter rodando.
10. **`cluster_version` no tfvars é metadado**: o emulador não implementa `UpdateClusterVersion` e a versão real do k3s é fixada pela imagem do MiniStack (`v1.31.4+k3s1`). Não alterar esse campo sem recriar o cluster do zero.
11. **Drift eterno de `key_id` no SSM**: o emulador não persiste o KMS key-id do parâmetro, então `terraform plan` sempre mostra ~4 updates in-place (SSM `key_id`, stage do APIGW, listener rule). Inofensivo e preexistente.
10. **Debug logs instrumentados** no ministack local (prefixo `DBG` em `/tmp/ministack.log`: `_get_q`, `_queue_by_arn`, fanout, introspecção) — resquício da investigação do item 9; inofensivos, mas reaparecem após cada restart (patch local).

## Fase 3 (próximos passos sugeridos)

- ~~Deploy de apps de teste no EKS gerenciados pelo ArgoCD~~ (feito: app-web via ECR + ALB; falta a Application do ArgoCD apontando para o remote do repo)
- ArgoCD Application para o path `k8s/app` (manifest pronto em `k8s/argocd/` — informar a URL do remote)
- Worker consumindo a `ministack-queue` (app-worker) publicando em Kafka.
