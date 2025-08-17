locals {
  namespace = "${var.project_name}-${var.env_name}"
}

module "network" {
  source       = "../../modules/providers/aws/network"
  region       = var.region
  project_name = var.project_name
  env_name     = var.env_name
  namespace    = local.namespace
}

module "iam" {
  source       = "../../modules/providers/aws/iam"
  project_name = var.project_name
  env_name     = var.env_name
  namespace    = local.namespace
}

module "ecr" {
  for_each     = toset(["${var.project_name}-backend-repo"])
  source       = "../../modules/providers/aws/ecr"
  project_name = var.project_name
  env_name     = var.env_name
  namespace    = local.namespace
  name         = each.key
}


##############################################################
#
# Backend Module
#
##############################################################

module "backend_security_group" {
  source = "../../modules/providers/aws/security-group"
  name   = "${local.namespace}-docker-swarm-manager-node-sg"
  vpc_id = module.network.vpc_id

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "backend" {
  source                = "../../modules/providers/aws/backend"
  vpc                   = module.network.vpc
  region                = var.region
  project_name          = var.project_name
  env_name              = var.env_name
  namespace             = local.namespace
  instance_type         = "c5n.large"
  functionality         = "backend"
  key_name              = "${local.namespace}-backend-key-pair"
  key_pair_file_path    = var.BACKEND_KEY_PAIR_PATH
  spot_price            = var.SPOT_PRICE
  user_data_script_path = "${path.module}/user-data.sh"
  iam_role_name         = module.iam.ecr_iam_role_name
  security_group_id     = module.backend_security_group.security_group_id
}
