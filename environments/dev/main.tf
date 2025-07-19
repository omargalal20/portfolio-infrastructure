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
  vpc          = module.network.vpc
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
    },
    # {
    #   from_port   = 8000
    #   to_port     = 8000
    #   protocol    = "tcp"
    #   cidr_blocks = ["0.0.0.0/0"]
    # },
    # # Allow inbound UDP from Cloudflare TURN server IPs for WebRTC media
    # {
    #   from_port = 1024 # Or a more specific range if known, but a wide ephemeral range is common
    #   to_port   = 65535
    #   protocol  = "udp"
    #   cidr_blocks = [
    #     "198.41.192.0/24",
    #     "198.41.200.0/24",
    #     # Add any other Cloudflare IP ranges if provided by documentation
    #   ]
    # },
    # # WebRTC/TURN typically uses UDP for media
    # {
    #   from_port   = 10000
    #   to_port     = 20000
    #   protocol    = "udp"
    #   cidr_blocks = ["0.0.0.0/0"]
    # },
    # # STUN/TURN signaling
    # {
    #   from_port   = 3478
    #   to_port     = 3478
    #   protocol    = "udp"
    #   cidr_blocks = ["0.0.0.0/0"]
    # },
    # {
    #   from_port   = 3478
    #   to_port     = 3478
    #   protocol    = "tcp"
    #   cidr_blocks = ["0.0.0.0/0"]
    # },
    # {
    #   from_port   = 5349
    #   to_port     = 5349
    #   protocol    = "tcp"
    #   cidr_blocks = ["0.0.0.0/0"]
    #   description = "TURN over TLS"
    # },
    # {
    #   from_port   = 5349
    #   to_port     = 5349
    #   protocol    = "udp"
    #   cidr_blocks = ["0.0.0.0/0"]
    #   description = "TURN over DTLS"
    # }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    },
    # Explicit Cloudflare tunnel egress (redundant but explicit)
    {
      from_port = 7844
      to_port   = 7844
      protocol  = "tcp"
      cidr_blocks = [
        "198.41.192.0/24",
        "198.41.200.0/24"
      ]
    },
    {
      from_port = 7844
      to_port   = 7844
      protocol  = "udp"
      cidr_blocks = [
        "198.41.192.0/24",
        "198.41.200.0/24"
      ]
    }
  ]
}

module "backend" {
  source             = "../../modules/providers/aws/backend"
  vpc                = module.network.vpc
  region             = var.region
  project_name       = var.project_name
  env_name           = var.env_name
  namespace          = local.namespace
  instance_type      = "t3.medium"
  functionality      = "backend"
  key_name           = "${local.namespace}-backend-key-pair"
  key_pair_file_path = var.BACKEND_KEY_PAIR_PATH
  iam_role_name      = module.iam.ecr_iam_role_name
  security_group_id  = module.backend_security_group.security_group_id
}
