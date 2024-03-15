provider "aws" {}

variable "project" {
    type = string
}

variable "environment" {
    type = string
}

variable "failover_server_is_active" {
    type    = bool
    default = false
}
