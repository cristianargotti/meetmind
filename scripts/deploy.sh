#!/usr/bin/env bash
# =============================================================================
# MeetMind — Production Deploy Script
# Build Docker image, push to ECR, deploy to EC2
# =============================================================================
set -euo pipefail

# --- Configuration ---
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-mibaggy-co}"
PROJECT="meetmind"
SSM_PREFIX="/${PROJECT}/production"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[DEPLOY]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# --- Step 0: Validate prerequisites ---
log "Validating prerequisites..."
command -v aws >/dev/null 2>&1 || err "aws CLI not found"
command -v docker >/dev/null 2>&1 || err "docker not found"

# --- Step 1: Get ECR repository URL ---
log "Getting ECR repository URL..."
ECR_REPO=$(aws ecr describe-repositories \
  --repository-names "${PROJECT}-backend" \
  --region "${AWS_REGION}" \
  --profile "${AWS_PROFILE}" \
  --query 'repositories[0].repositoryUri' \
  --output text 2>/dev/null) || err "ECR repo not found. Run: cd infra && terraform apply"

TAG="${1:-latest}"
IMAGE="${ECR_REPO}:${TAG}"
log "Target image: ${IMAGE}"

# --- Step 2: Build Docker image ---
log "Building Docker image..."
docker build -t "${IMAGE}" -f backend/Dockerfile backend/

# --- Step 3: Login to ECR ---
log "Logging in to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" --profile "${AWS_PROFILE}" | \
  docker login --username AWS --password-stdin "${ECR_REPO%%/*}"

# --- Step 4: Push to ECR ---
log "Pushing image to ECR..."
docker push "${IMAGE}"
log "Image pushed: ${IMAGE}"

# --- Step 5: Get EC2 public IP ---
log "Getting EC2 instance IP..."
EC2_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${PROJECT}-production" "Name=instance-state-name,Values=running" \
  --region "${AWS_REGION}" \
  --profile "${AWS_PROFILE}" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text 2>/dev/null) || err "EC2 instance not found"

log "EC2 IP: ${EC2_IP}"

# --- Step 6: Get secrets from SSM ---
log "Fetching secrets from SSM..."
OPENAI_KEY=$(aws ssm get-parameter \
  --name "${SSM_PREFIX}/openai-api-key" \
  --with-decryption \
  --region "${AWS_REGION}" \
  --profile "${AWS_PROFILE}" \
  --query 'Parameter.Value' \
  --output text 2>/dev/null) || err "SSM parameter not found: ${SSM_PREFIX}/openai-api-key"

HF_TOKEN=$(aws ssm get-parameter \
  --name "${SSM_PREFIX}/huggingface-token" \
  --with-decryption \
  --region "${AWS_REGION}" \
  --profile "${AWS_PROFILE}" \
  --query 'Parameter.Value' \
  --output text 2>/dev/null) || true

# --- Step 7: Deploy to EC2 ---
log "Deploying to EC2..."

# Determine SSH key
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/meetmind.pem}"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

# Upload docker-compose + Caddyfile + .env.production
log "Uploading deployment files..."
scp ${SSH_OPTS} -i "${SSH_KEY}" \
  backend/docker-compose.prod.yml \
  backend/Caddyfile \
  backend/.env.production \
  "ec2-user@${EC2_IP}:/opt/meetmind/"

# Login to ECR on EC2, pull new image, and restart
log "Pulling image and restarting services..."
ssh ${SSH_OPTS} -i "${SSH_KEY}" "ec2-user@${EC2_IP}" bash -s <<REMOTE
set -e
cd /opt/meetmind

# ECR login
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin "${ECR_REPO%%/*}"

# Export variables for docker-compose
export ECR_REPO="${ECR_REPO}"
export TAG="${TAG}"
export MEETMIND_OPENAI_API_KEY="${OPENAI_KEY}"
export MEETMIND_HUGGINGFACE_TOKEN="${HF_TOKEN}"

# Pull and restart
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d --remove-orphans

# Wait for health
echo "Waiting for health check..."
for i in {1..30}; do
  if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ Backend healthy!"
    break
  fi
  sleep 2
done
REMOTE

# --- Step 8: Verify ---
log "Verifying deployment..."
sleep 5
DOMAIN=$(grep -oP '^\S+' backend/Caddyfile | head -1 | tr -d '{')

if curl -sf "http://${EC2_IP}:8000/health" > /dev/null 2>&1; then
  log "✅ Deploy successful!"
  log "Backend: http://${EC2_IP}:8000/health"
  log "HTTPS: https://${DOMAIN} (once DNS is pointed)"
else
  warn "Backend not responding yet. Check logs:"
  warn "ssh -i ${SSH_KEY} ec2-user@${EC2_IP} 'cd /opt/meetmind && docker compose -f docker-compose.prod.yml logs'"
fi
