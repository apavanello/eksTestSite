variable "name_prefix" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
