# eksTestSite — targets de conveniência sobre o stack Terraform/MiniStack
# Requer: terraform, aws cli, kubectl, helm, docker, jq
TF_DIR := terraform
ENDPOINT := http://localhost:4566
AWS_ENV := AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
KUBECONFIG := $(abspath $(TF_DIR)/.kube/test-cluster.yaml)

.PHONY: help plan apply fmt validate k8s pods argocd karpenter test reset ecr-login kafka-topic clean-state

help: ## Lista os targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-14s %s\n", $$1, $$2}'

# ── Terraform ────────────────────────────────────────────────────────────
plan: ## terraform plan
	cd $(TF_DIR) && terraform plan

apply: ## terraform apply (recria tudo; use após restart do ministack)
	cd $(TF_DIR) && terraform apply -auto-approve

fmt: ## terraform fmt + validate
	cd $(TF_DIR) && terraform fmt -recursive && terraform validate

validate: fmt

clean-state: ## Remove estado local (backup) — usado após wipe do emulador
	cd $(TF_DIR) && cp terraform.tfstate terraform.tfstate.stale-$$(date +%Y%m%d-%H%M%S) 2>/dev/null; rm -f terraform.tfstate terraform.tfstate.backup terraform.tfstate.*.backup
	@ls -1t $(TF_DIR)/terraform.tfstate.stale-* 2>/dev/null | tail -n +4 | xargs -r rm -f ## retenção: mantém só os 3 backups mais recentes

# ── Kubernetes (k3s) ─────────────────────────────────────────────────────
k8s: ## kubectl get nodes + pods -A
	KUBECONFIG=$(KUBECONFIG) kubectl get nodes -o wide
	KUBECONFIG=$(KUBECONFIG) kubectl get pods -A -o wide

pods: k8s

argocd: ## Senha admin do ArgoCD + port-forward da UI (http://localhost:18080)
	@KUBECONFIG=$(KUBECONFIG) kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d; echo
	@echo "UI: http://localhost:18080 (login: admin)"
	KUBECONFIG=$(KUBECONFIG) kubectl -n argocd port-forward svc/argocd-server 18080:80

karpenter: ## Logs do controller Karpenter (erros de emulação são esperados)
	KUBECONFIG=$(KUBECONFIG) kubectl logs -n karpenter deploy/karpenter --tail=50

# ── Validações ponta a ponta ─────────────────────────────────────────────
test: ## Validações: APIGW, ALB, SSM, KMS, SNS→SQS, Kafka
	$(MAKE) test-apigw test-alb test-ssm test-kms test-sns test-kafka

test-apigw: ## APIGW direto (lambda proxy /v1/hello)
	@URL=$$(cd $(TF_DIR) && terraform output -json apigateway | jq -r .invoke_url); \
	echo "GET $$URL"; curl -s -w "\nHTTP %{http_code}\n" "$$URL"

test-alb: ## ALB → APIGW → Lambda via header Host
	@HOST=$$(cd $(TF_DIR) && terraform output -json elb | jq -r .lb_dns_name); \
	echo "GET /v1/hello (Host: $$HOST)"; \
	curl -s -w "\nHTTP %{http_code}\n" -H "Host: $$HOST" "$(ENDPOINT)/v1/hello"

test-ssm: ## SSM get-parameter
	@$(AWS_ENV) aws --endpoint-url $(ENDPOINT) ssm get-parameter \
		--name /ministack/app/config --with-decryption --output json | jq -r .Parameter.Value

test-kms: ## KMS roundtrip (usa fileb:// — blob params exigem arquivo)
	@KEY=$$(cd $(TF_DIR) && terraform output -json kms | jq -r .key_id); \
	CT=$$($(AWS_ENV) aws --endpoint-url $(ENDPOINT) kms encrypt --key-id $$KEY \
		--plaintext "make-test-$$(date +%s)" --encryption-context env=test --output json | jq -r .CiphertextBlob); \
	echo "$$CT" | base64 -d > /tmp/ct.bin; \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) kms decrypt --key-id $$KEY \
		--ciphertext-blob fileb:///tmp/ct.bin --encryption-context env=test --output json \
		| jq -r .Plaintext | base64 -d; echo

test-sns: ## SNS publish → SQS receive
	@TOPIC=$$(cd $(TF_DIR) && terraform output -json messaging | jq -r .topic_arn); \
	QUEUE=$$(cd $(TF_DIR) && terraform output -json messaging | jq -r .queue_url); \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sns publish --topic-arn $$TOPIC \
		--message "make-sns-$$(date +%s)" >/dev/null; sleep 1; \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs receive-message --queue-url $$QUEUE \
		--max-number-of-messages 5 --output json | jq -r '.Messages[].Body' 2>/dev/null

test-kafka: ## Kafka: cria tópico no Redpanda
	docker exec redpanda rpk topic create make-topic -p 1 || true
	docker exec redpanda rpk topic list

ecr-login: ## docker login no ECR local
	@$(AWS_ENV) aws --endpoint-url $(ENDPOINT) ecr get-login-password | docker login --username AWS --password-stdin localhost:4566

# ── Manutenção ───────────────────────────────────────────────────────────
reset: ## Reinicia o ministack (APAGA todo o estado emulado; rode `make apply` depois)
	systemctl --user restart ministack
	@echo "Estado AWS emulado zerado. Rode: make apply"
