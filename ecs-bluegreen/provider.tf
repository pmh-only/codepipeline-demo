terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "region" {
  default = "ap-northeast-2"
}

variable "project_name" {
  default = "project"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project=var.project_name
    }
  }
}

provider "local" {

}

data "aws_caller_identity" "caller" {
  
}
