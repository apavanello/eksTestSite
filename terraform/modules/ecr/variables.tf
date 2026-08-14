variable "name_prefix" {
  type = string
}

variable "repositories" {
  type        = list(string)
  description = "Nomes dos repositorios ECR"
  default     = []
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
