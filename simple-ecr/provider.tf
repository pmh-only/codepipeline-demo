terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
}

data "aws_caller_identity" "caller" {
  
}
