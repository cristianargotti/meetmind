#!/usr/bin/env bash
set -euo pipefail

echo "=== MeetMind EC2 Start ==="

# 1. Fetch secrets from SSM
echo "[1/4] Fetching secrets from SSM..."
OPENAI_KEY=$(aws ssm get-parameter --name "/meetmind/production/openai-api-key" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
HF_TOKEN=$(aws ssm get-parameter --name "/meetmind/production/huggingface-token" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
echo "  OpenAI key: ${OPENAI_KEY:0:10}..."
echo "  HF token: ${HF_TOKEN:0:5}..."

# 2. Create .env from production defaults + secrets
echo "[2/4] Creating .env..."
cd /opt/meetmind/backend
cp .env.production .env
echo "" >> .env
echo "OPENAI_API_KEY=${OPENAI_KEY}" >> .env
echo "HUGGINGFACE_TOKEN=${HF_TOKEN}" >> .env
echo "  .env created with $(wc -l < .env) lines"

# 3. Start backend directly (no Caddy for MVP — HTTP only)
echo "[3/4] Starting backend container..."
sudo docker stop meetmind-backend 2>/dev/null || true
sudo docker rm meetmind-backend 2>/dev/null || true
sudo docker run -d \
  --name meetmind-backend \
  --restart unless-stopped \
  --env-file .env \
  -p 80:8000 \
  meetmind-backend:v1

echo "[4/4] Waiting for health check..."
sleep 5
if curl -sf http://localhost/health > /dev/null 2>&1; then
  echo "✅ MeetMind is LIVE at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'IP')"
else
  echo "⚠️  Health check failed, checking logs..."
  sudo docker logs meetmind-backend --tail 20
fi
