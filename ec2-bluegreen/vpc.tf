module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}c"]

  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]
  public_subnet_names = [
    "${var.project_name}-subnet-public-a",
    "${var.project_name}-subnet-public-c"
  ]

  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  private_subnet_names = [
    "${var.project_name}-subnet-private-a",
    "${var.project_name}-subnet-private-c"
  ]

  enable_nat_gateway = true
  enable_dns_support = true
  enable_dns_hostnames = true

  one_nat_gateway_per_az = true
}
