provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Environment = "Development"
      Project     = "Portfolio Infrastructure"
      Owner       = "Omar Elhanafy"
    }
  }
}
