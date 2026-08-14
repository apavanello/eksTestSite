variable "region" {
  description = "Região AWS emulada"
  type        = string
  default     = "us-east-1"
}

variable "ministack_endpoint" {
  description = "Endpoint do MiniStack (emulador AWS local)"
  type        = string
  default     = "http://localhost:4566"
}

variable "account_id" {
  description = "Account ID emulado pelo MiniStack"
  type        = string
  default     = "000000000000"
}

variable "environment" {
  description = "Nome do ambiente"
  type        = string
  default     = "local"
}

variable "resource_prefix" {
  description = "Prefixo de nomes de todos os recursos"
  type        = string
  default     = "ministack"
}

variable "cluster_name" {
  description = "Nome do cluster EKS (gerencia o container k3s do MiniStack)"
  type        = string
  default     = "test-cluster"
}

variable "cluster_version" {
  description = "Versão do Kubernetes (aceita pelo MiniStack; o k3s real roda o que a imagem EKS_K3S_IMAGE oferece)"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR da VPC emulada"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "kafka_cluster_name" {
  description = "Nome do cluster MSK (Kafka) emulado"
  type        = string
  default     = "ministack-kafka"
}

variable "kafka_version" {
  description = "Versão do Kafka reportada pelo MiniStack"
  type        = string
  default     = "3.6.0"
}

variable "kafka_instance_type" {
  description = "Tipo de instância do broker Kafka"
  type        = string
  default     = "kafka.t3.small"
}

variable "ecr_repositories" {
  description = "Repositórios ECR a criar"
  type        = list(string)
  default     = ["app-api", "app-worker", "app-web"]
}

variable "argocd_enabled" {
  description = "Instala o ArgoCD no cluster EKS"
  type        = bool
  default     = true
}

variable "karpenter_enabled" {
  description = "Instala o Karpenter no cluster EKS (provisioning emulado pelo MiniStack)"
  type        = bool
  default     = true
}

variable "argo_cd_namespace" {
  description = "Namespace do ArgoCD"
  type        = string
  default     = "argocd"
}

variable "karpenter_namespace" {
  description = "Namespace do Karpenter"
  type        = string
  default     = "karpenter"
}

variable "addons_enabled" {
  description = "Aplica os add-ons (ArgoCD/Karpenter/CoreDNS). Fase 2 do deploy: requer o kubeconfig da fase 1."
  type        = bool
  default     = true
}
