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
test: ## Validações: APIGW, ALB/API, app, SSM, KMS, SNS→SQS, DLQ, Kafka
	$(MAKE) test-apigw test-alb test-app test-ssm test-kms test-sns test-dlq test-kafka

test-apigw: ## APIGW direto (lambda proxy /v1/hello)
	@URL=$$(cd $(TF_DIR) && terraform output -json apigateway | jq -r .invoke_url); \
	echo "GET $$URL"; curl -s -w "\nHTTP %{http_code}\n" "$$URL"

test-alb: ## ALB → APIGW → Lambda via header Host
	@HOST=$$(cd $(TF_DIR) && terraform output -json elb | jq -r .lb_dns_name); \
	echo "GET /v1/hello (Host: $$HOST)"; \
	curl -s -w "\nHTTP %{http_code}\n" -H "Host: $$HOST" "$(ENDPOINT)/v1/hello"

test-app: ## ALB → app-web (whoami) — path / (o /health do emulador tem precedência)
	@HOST=$$(cd $(TF_DIR) && terraform output -json elb | jq -r .lb_dns_name); \
	echo "GET / (Host: $$HOST)"; \
	curl -s -w "\nHTTP %{http_code}\n" -H "Host: $$HOST" "$(ENDPOINT)/" | head -6

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

test-sns: ## SNS publish → SQS receive (fila descartável — determinístico, sem competir com o Karpenter)
	@set -e; \
	PROBE=make-sns-probe-$$RANDOM; \
	PURL=$$($(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs create-queue --queue-name $$PROBE --query QueueUrl --output text); \
	PARN=$$($(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs get-queue-attributes --queue-url $$PURL \
		--attribute-names QueueArn --query Attributes.QueueArn --output text); \
	TOPIC=$$(cd $(TF_DIR) && terraform output -json messaging | jq -r .topic_arn); \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sns subscribe --topic-arn $$TOPIC --protocol sqs \
		--notification-endpoint $$PARN >/dev/null; \
	MSG="make-sns-$$(date +%s)"; \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sns publish --topic-arn $$TOPIC --message "$$MSG" >/dev/null; \
	sleep 1; \
	echo "recebido na fila probe:"; \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs receive-message --queue-url $$PURL \
		--max-number-of-messages 5 --output json | jq -r '.Messages[0].Body // "FALHOU"'; \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs delete-queue --queue-url $$PURL

test-dlq: ## Redrive: valida RedrivePolicy da fila real + redrive funcional em fila descartável
	@set -e; \
	QUEUE=$$($(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs get-queue-url --queue-name ministack-queue --query QueueUrl --output text); \
	echo "RedrivePolicy da ministack-queue:"; \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs get-queue-attributes --queue-url $$QUEUE \
		--attribute-names RedrivePolicy --output json | jq -r .Attributes.RedrivePolicy; \
	PROBE=make-dlq-probe-$$RANDOM; \
	PDLQ_ARN=$$($(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs create-queue --queue-name $$PROBE-dlq >/dev/null && \
		$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs get-queue-attributes \
		--queue-url $$($(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs get-queue-url --queue-name $$PROBE-dlq --query QueueUrl --output text) \
		--attribute-names QueueArn --query Attributes.QueueArn --output text); \
	PURL=$$($(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs create-queue --queue-name $$PROBE-main \
		--attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$$PDLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}" \
		--query QueueUrl --output text); \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs send-message --queue-url $$PURL --message-body "dlq-probe" >/dev/null; \
	for i in 1 2 3 4; do \
		$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs receive-message --queue-url $$PURL \
			--visibility-timeout 1 --max-number-of-messages 10 >/dev/null; sleep 2; \
	done; \
	echo "Redrive funcional (probe após 4 receives):"; \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs receive-message \
		--queue-url $$($(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs get-queue-url --queue-name $$PROBE-dlq --query QueueUrl --output text) \
		--output json | jq -r '.Messages[0].Body // "FALHOU"'; \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs delete-queue --queue-url $$PURL; \
	$(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs delete-queue --queue-url $$($(AWS_ENV) aws --endpoint-url $(ENDPOINT) sqs get-queue-url --queue-name $$PROBE-dlq --query QueueUrl --output text)

test-kafka: ## Kafka: cria tópico no Redpanda
	docker exec redpanda rpk topic create make-topic -p 1 || true
	docker exec redpanda rpk topic list

ecr-login: ## docker login no ECR local
	@$(AWS_ENV) aws --endpoint-url $(ENDPOINT) ecr get-login-password | docker login --username AWS --password-stdin localhost:4566

# ── App de teste (Fase 2) ─────────────────────────────────────────────────
APP_IMAGE ?= v1
ECR_ALIAS := 000000000000.dkr.ecr.us-east-1.amazonaws.com

app-image: ## Build/push do app de teste (traefik/whoami re-tagged) no ECR local
	docker pull traefik/whoami:latest
	docker tag traefik/whoami:latest localhost:4566/ministack-app-web:$(APP_IMAGE)
	@$(MAKE) ecr-login
	docker push localhost:4566/ministack-app-web:$(APP_IMAGE)

# ── Manutenção ───────────────────────────────────────────────────────────
reset: ## Reinicia o ministack (APAGA todo o estado emulado; rode `make apply` depois)
	systemctl --user restart ministack
	@echo "Estado AWS emulado zerado. Rode: make apply"
