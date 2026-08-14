variable "name_prefix" {
  type = string
}

variable "kms_key_id" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
