data "aws_ami" "latest_amazon_linux_image" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "tf_key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "tf_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = var.key_pair_file_path
}

resource "aws_iam_instance_profile" "backend_instance_profile" {
  name = "${var.namespace}-${var.functionality}-profile"
  role = var.iam_role_name
}

resource "aws_instance" "backend_instance" {
  ami                         = data.aws_ami.latest_amazon_linux_image.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.vpc.public_subnets[0]
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.backend_instance_profile.name
  user_data_base64            = var.user_data_script_path != "" ? base64encode(file(var.user_data_script_path)) : null

  # Spot instance configuration
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price                      = var.spot_price
      spot_instance_type             = "persistent"
      instance_interruption_behavior = "stop"
    }
  }

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.namespace}-${var.functionality}-instance"
  }

  depends_on = [aws_key_pair.tf_key_pair]
}
