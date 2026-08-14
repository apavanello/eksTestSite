variable "cluster_name" {
  type = string
}

variable "kubeconfig_path" {
  type = string
}

variable "host_gateway_ip" {
  type = string
}

variable "cluster_created_at" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "in_cluster_aws_endpoint" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "argocd_enabled" {
  type    = bool
  default = true
}

variable "karpenter_enabled" {
  type    = bool
  default = true
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "karpenter_namespace" {
  type    = string
  default = "karpenter"
}

variable "karpenter_controller_role" {
  type = string
}

variable "karpenter_node_profile" {
  type = string
}

variable "karpenter_interruption_queue" {
  type    = string
  default = ""
}

variable "argocd_chart_version" {
  type    = string
  default = ""
}

variable "karpenter_repository" {
  type    = string
  default = "oci://public.ecr.aws/karpenter"
}

variable "karpenter_chart_version" {
  type    = string
  default = "1.1.3"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
