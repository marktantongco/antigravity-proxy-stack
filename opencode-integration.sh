#!/bin/bash
# OpenCode Code Generation Backend Integration
# Configures model endpoint bridging to claw-code.codes

echo "=== OPENCODE INTEGRATION ==="

CLAW_CODE_TOKEN="${AG_CLAW_CODE_TOKEN:-}"
AG_PROXY_AI_URL="${AG_PROXY_AI_URL:-http://ag-proxy-ai:3002}"

cat > /home/ubuntu/proxy-stack/opencode-config.env << EOF
# OpenCode Backend Configuration
OPENCODE_PORT=8000
MODEL_PROVIDER=claw-code
MODEL_ENDPOINT=https://claw-code.codes/api/v1/generate
AUTH_TOKEN=$CLAW_CODE_TOKEN
AG_PROXY_AI_URL=$AG_PROXY_AI_URL

# Generation parameters
MAX_TOKENS=4096
TEMPERATURE=0.7
TOP_P=0.95
TOP_K=40

# Rate limiting
MAX_REQUESTS_PER_MINUTE=60
MAX_TOKENS_PER_DAY=1000000

# Logging
LOG_LEVEL=info
LOG_FORMAT=json
EOF

# Create OpenCode service override
sudo mkdir -p /etc/systemd/system/proxy-stack.service.d
sudo tee /etc/systemd/system/proxy-stack.service.d/opencode.conf > /dev/null << EOF
[Service]
EnvironmentFile=/home/ubuntu/proxy-stack/opencode-config.env
EOF

sudo systemctl daemon-reload

echo ""
echo "=== OPENCODE CONFIGURATION ==="
echo "Config: /home/ubuntu/proxy-stack/opencode-config.env"
echo ""
echo "Model routing:"
echo "  User Request -> Nginx -> OpenCode -> claw-code.codes"
echo "  User Request -> Nginx -> OpenCode -> AG Proxy AI -> Anthropic/OpenAI"
echo ""
echo "API endpoints:"
echo "  POST https://localhost/api/code/generate"
echo "  POST https://localhost/api/code/complete"
echo "  GET  https://localhost/api/code/models"
