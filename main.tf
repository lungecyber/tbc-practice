provider "aws" {
    shared_config_files      = ["/home/hgresa/.aws/config"]
    shared_credentials_files = ["/home/hgresa/.aws/credentials"]
    profile                  = "personal-acc-terraform-practice"
}

variable "project" {
    type = string
}

variable "environment" {
    type = string
}
