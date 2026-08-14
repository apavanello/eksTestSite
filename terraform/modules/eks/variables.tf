variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.30"
}

variable "region" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "kubeconfig_path" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
