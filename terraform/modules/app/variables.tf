variable "tg_arn" {
  description = "ARN do target group default do ALB (ministack-tg)"
  type        = string
}

variable "node_port" {
  description = "NodePort do Service do app (target registrado no ALB)"
  type        = number
}

variable "kubeconfig_path" {
  description = "Caminho absoluto do kubeconfig do cluster"
  type        = string
}

variable "endpoint" {
  description = "Endpoint do emulador (MiniStack)"
  type        = string
}

variable "cluster_created_at" {
  description = "Timestamp de criação do cluster — força re-registro quando o cluster é recriado"
  type        = string
}

variable "manifests_dir" {
  description = "Diretório absoluto dos manifests do app (k8s/app)"
  type        = string
}
