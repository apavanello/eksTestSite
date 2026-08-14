variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "api_target_host" {
  type    = string
  default = ""
}

variable "api_path_pattern" {
  type    = string
  default = "/v1/*"
}
