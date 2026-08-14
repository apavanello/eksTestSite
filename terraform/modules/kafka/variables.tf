variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kafka_version" {
  type    = string
  default = "3.6.0"
}

variable "instance_type" {
  type    = string
  default = "kafka.t3.small"
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "endpoint" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "bootstrap_brokers" {
  type        = string
  description = "Bootstrap retornado pelo MiniStack (MINISTACK_MSK_BOOTSTRAP)"
  default     = "host.docker.internal:9092"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
