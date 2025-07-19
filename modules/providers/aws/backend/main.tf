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

  root_block_device {
    volume_size = 16
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.key_pair_file_path)
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "ec2-setup.sh"
    destination = "/home/ec2-user/ec2-setup.sh"
  }

  provisioner "file" {
    source      = "portfolio-backend/docker-compose.yml"
    destination = "/home/ec2-user/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install dos2unix -y",
      "dos2unix /home/ec2-user/ec2-setup.sh",
      "sudo chmod +x /home/ec2-user/ec2-setup.sh",
      "echo Starting ec2-setup",
      "sh /home/ec2-user/ec2-setup.sh"
    ]
  }

  tags = {
    Name = "${var.namespace}-${var.functionality}-instance"
  }

  depends_on = [aws_key_pair.tf_key_pair]
}
