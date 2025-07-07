terraform {
  required_version = ">=1.2.3"

  backend "s3" {
    bucket  = "portfolio-infrastructure-dev-terraform-state-bucket"
    key     = "terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
    profile = "portfolio"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.4"
    }
  }
}

