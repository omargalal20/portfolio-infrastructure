locals {
  subnet_ips = {
    public_a = "10.0.1.0/24" # Changed from 172.31.64.0/24
  }
  cidr = "10.0.0.0/16" # Changed from 172.31.0.0/16
}

module "vpc" {
  source         = "terraform-aws-modules/vpc/aws"
  version        = "5.1.0"
  name           = "${var.namespace}-vpc"
  cidr           = local.cidr
  azs            = ["us-east-2c"]
  public_subnets = [local.subnet_ips.public_a]

  enable_nat_gateway   = false
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Ensure proper internet gateway setup
  create_igw = true

  tags = {
    Name = "${var.namespace}-vpc"
  }
}
