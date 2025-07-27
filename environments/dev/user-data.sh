#!/bin/bash

# User Data Script for Spot Instance Auto-Recovery
# This script runs on every instance start/restart

set -e  # Exit on any error

# Log function for better debugging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/user-data.log
}

log "Starting User Data script execution..."

# Update the system
log "Updating system packages..."
sudo yum update -y

# Install additional tools
log "Installing required packages..."
sudo yum install -y git unzip amazon-ecr-credential-helper htop jq

# Install docker-engine
log "Installing Docker..."
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
sudo systemctl daemon-reload
log "Docker installed and started..."

# Install Docker Compose
log "Installing Docker Compose..."
sudo curl -SL https://github.com/docker/compose/releases/download/v2.23.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
docker-compose --version
log "Docker Compose installed..."

# Install Docker Machine
log "Installing Docker Machine..."
sudo curl -L https://github.com/docker/machine/releases/download/v0.12.2/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine
chmod +x /tmp/docker-machine
sudo cp /tmp/docker-machine /usr/local/bin

# Create swap file for better performance
log "Setting up swap file..."
sudo fallocate -l 8G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=8192
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Install cloudflared
log "Installing Cloudflared..."
curl -fsSl https://pkg.cloudflare.com/cloudflared-ascii.repo | sudo tee /etc/yum.repos.d/cloudflared.repo
sudo yum install cloudflared -y

# Install dos2unix for file conversion
log "Installing dos2unix..."
sudo yum install dos2unix -y

# Create application directory
log "Creating application directory..."
sudo mkdir -p /opt/portfolio-backend
sudo chown ec2-user:ec2-user /opt/portfolio-backend
cd /opt/portfolio-backend

# Fetch secrets from AWS Secrets Manager
log "Fetching secrets from AWS Secrets Manager..."
log "Checking if AWS CLI is available..."
if ! command -v aws &> /dev/null; then
    log "ERROR: AWS CLI is not installed"
    exit 1
fi

log "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    log "ERROR: AWS credentials not configured or invalid"
    exit 1
fi

log "Checking if secret exists..."
if ! aws secretsmanager describe-secret --secret-id "portfolio-dev-backend-secrets" --region "us-east-2" &> /dev/null; then
    log "ERROR: Secret 'portfolio-dev-backend-secrets' does not exist in us-east-2"
    log "Creating empty .env file as fallback..."
    touch .env
else
    log "Secret exists, proceeding to retrieve..."
    
    SECRETS_RESPONSE=$(aws secretsmanager get-secret-value \
        --secret-id "portfolio-dev-backend-secrets" \
        --region "us-east-2" \
        --query 'SecretString' \
        --output text 2>&1)

    SECRETS_EXIT_CODE=$?

    # Check if secrets were retrieved successfully
    if [ $SECRETS_EXIT_CODE -ne 0 ] || [ -z "$SECRETS_RESPONSE" ]; then
        log "ERROR: Failed to retrieve secrets from AWS Secrets Manager"
        log "Exit code: $SECRETS_EXIT_CODE"
        log "Response: $SECRETS_RESPONSE"
        log "Creating empty .env file as fallback..."
        touch .env
    else
        log "Secrets retrieved successfully, creating .env file..."
        log "Response length: ${#SECRETS_RESPONSE} characters"
        
        # Try to parse JSON and create .env file
        if echo "$SECRETS_RESPONSE" | jq -e . >/dev/null 2>&1; then
            echo "$SECRETS_RESPONSE" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' > .env
            log "Successfully parsed JSON secrets and created .env file"
        else
            log "WARNING: Secrets response is not valid JSON, treating as plain text..."
            log "First 100 characters of response: ${SECRETS_RESPONSE:0:100}"
            # If it's not JSON, treat it as plain text (key=value format)
            echo "$SECRETS_RESPONSE" > .env
        fi
    fi
fi

# Verify .env file was created
if [ ! -f .env ]; then
    log "ERROR: .env file was not created"
    touch .env
fi

# If .env file is empty, create a basic one with default values
if [ ! -s .env ]; then
    log "WARNING: .env file is empty, creating basic configuration..."
    cat > .env << EOF
# Basic configuration - update with actual values
DATABASE_URL=postgresql://localhost:5432/portfolio
API_KEY=your-api-key-here
ENVIRONMENT=development
EOF
    log "Created basic .env file with default values"
fi

# Convert .env file to Unix format
log "Converting .env file to Unix format..."
dos2unix .env

# Log the .env file contents (without sensitive values)
log "Environment variables loaded:"
if [ -s .env ]; then
    while IFS= read -r line; do
        if [[ $line =~ ^[^#]*= ]]; then
            key=$(echo "$line" | cut -d'=' -f1)
            log "  - $key=***"
        fi
    done < .env
else
    log "  - No environment variables found"
fi

# Get ECR login token
log "Logging into ECR..."
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-2.amazonaws.com

# Get the latest image from ECR
log "Fetching latest ECR image..."
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-2.amazonaws.com
ECR_REPOSITORY="portfolio-backend-repo"

# Get the latest image tag
LATEST_IMAGE_TAG=$(aws ecr describe-images \
    --repository-name "$ECR_REPOSITORY" \
    --region us-east-2 \
    --query 'imageDetails[?imageTags!=null] | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
    --output text)

if [ "$LATEST_IMAGE_TAG" = "None" ] || [ -z "$LATEST_IMAGE_TAG" ]; then
    log "No tagged images found, using 'latest'"
    LATEST_IMAGE_TAG="latest"
fi

log "Latest image tag: $LATEST_IMAGE_TAG"

# Pull the latest image
log "Pulling latest Docker image..."
docker pull "$ECR_REGISTRY/$ECR_REPOSITORY:$LATEST_IMAGE_TAG"

# Create docker-compose.yml with the latest image
log "Creating docker-compose.yml..."
cat > docker-compose.yml << EOF
name: portfolio

services:
  backend:
    container_name: backend
    image: $ECR_REGISTRY/$ECR_REPOSITORY:$LATEST_IMAGE_TAG
    network_mode: host
    env_file:
      - .env
    restart: unless-stopped
    pull_policy: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

# Fetch Cloudflare tunnel token from AWS Secrets Manager
log "Fetching Cloudflare tunnel token from AWS Secrets Manager..."
CLOUDFLARE_SECRET_RESPONSE=$(aws secretsmanager get-secret-value \
    --secret-id "cloudflare-dev-tunnel" \
    --region "us-east-2" \
    --query 'SecretString' \
    --output text 2>&1)

CLOUDFLARE_SECRET_EXIT_CODE=$?

if [ $CLOUDFLARE_SECRET_EXIT_CODE -ne 0 ] || [ -z "$CLOUDFLARE_SECRET_RESPONSE" ]; then
    log "ERROR: Failed to retrieve Cloudflare tunnel token"
    log "Exit code: $CLOUDFLARE_SECRET_EXIT_CODE"
    log "Response: $CLOUDFLARE_SECRET_RESPONSE"
    log "Skipping Cloudflared service installation..."
else
    log "Cloudflare secret retrieved successfully"
    
    # Extract token from JSON response
    if echo "$CLOUDFLARE_SECRET_RESPONSE" | jq -e . >/dev/null 2>&1; then
        CLOUDFLARE_TOKEN=$(echo "$CLOUDFLARE_SECRET_RESPONSE" | jq -r '.token')
        log "Successfully extracted Cloudflare token"
    else
        log "WARNING: Cloudflare secret response is not valid JSON"
        log "First 100 characters of response: ${CLOUDFLARE_SECRET_RESPONSE:0:100}"
        CLOUDFLARE_TOKEN=""
    fi
    
    # Install cloudflared service with token if available
    if [ -n "$CLOUDFLARE_TOKEN" ] && [ "$CLOUDFLARE_TOKEN" != "null" ]; then
        log "Installing Cloudflared service with token..."
        sudo cloudflared service install "$CLOUDFLARE_TOKEN"
        log "Cloudflared service installed successfully"
    else
        log "ERROR: Invalid Cloudflare token, skipping service installation"
    fi
fi

# Stop any existing containers
log "Stopping existing containers..."
docker-compose down || true

# Start the application
log "Starting the backend application..."
docker-compose up -d

# Wait for the container to be healthy
log "Waiting for container to be ready..."
sleep 30

# Check if container is running
if docker ps | grep -q backend; then
    log "Backend container is running successfully!"
    log "Container logs:"
    docker logs backend --tail 20
else
    log "ERROR: Backend container failed to start!"
    docker-compose logs
    exit 1
fi

# Set up log rotation for user-data logs
log "Setting up log rotation..."
sudo tee /etc/logrotate.d/user-data << EOF
/var/log/user-data.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

log "User Data script completed successfully!" 