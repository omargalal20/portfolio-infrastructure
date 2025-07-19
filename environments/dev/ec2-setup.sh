#!/bin/bash

# Update the system
sudo yum update -y

# Install additional tools
sudo yum install -y git unzip amazon-ecr-credential-helper htop

# Install docker-engine
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
sudo systemctl daemon-reload
echo "Docker installed..."

# Install Docker Compose
sudo curl -SL https://github.com/docker/compose/releases/download/v2.23.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
docker-compose --version
echo "docker-compose installed..."

# Install Docker Machine
sudo curl -L https://github.com/docker/machine/releases/download/v0.12.2/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine
chmod +x /tmp/docker-machine
sudo cp /tmp/docker-machine /usr/local/bin

# Create a 4GB swap file
sudo fallocate -l 8G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=8192

# Secure the swap file
sudo chmod 600 /swapfile

# Set up the swap area
sudo mkswap /swapfile

# Enable the swap file
sudo swapon /swapfile

# Make the swap file permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Optional: Make Linux use swap less aggressively
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Add cloudflared.repo to /etc/yum.repos.d/ 
curl -fsSl https://pkg.cloudflare.com/cloudflared-ascii.repo | sudo tee /etc/yum.repos.d/cloudflared.repo

# install cloudflared
sudo yum install cloudflared -y