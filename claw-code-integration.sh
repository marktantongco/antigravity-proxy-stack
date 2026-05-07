#!/bin/bash
# Claw-Code.codes Service Endpoint Integration
# Configures endpoint bridging and authentication

echo "=== CLAW-CODE.CODES INTEGRATION ==="

CLAW_CODE_TOKEN="${AG_CLAW_CODE_TOKEN:-}"
if [ -z "$CLAW_CODE_TOKEN" ]; then
    echo "WARNING: AG_CLAW_CODE_TOKEN not set. Get token from https://claw-code.codes/dashboard"
    echo "Set it: export AG_CLAW_CODE_TOKEN=your_token_here"
fi

# Create systemd drop-in for proxy stack
sudo mkdir -p /etc/systemd/system/proxy-stack.service.d
sudo tee /etc/systemd/system/proxy-stack.service.d/claw-code.conf > /dev/null << EOF
[Service]
Environment="CLAW_CODE_ENDPOINT=https://claw-code.codes"
Environment="CLAW_CODE_API_VERSION=v1"
Environment="CLAW_CODE_TOKEN=$CLAW_CODE_TOKEN"
EOF

sudo systemctl daemon-reload

# Test connectivity
echo "Testing claw-code.codes connectivity..."
if curl -sf -o /dev/null -w "%{http_code}" https://claw-code.codes > /dev/null 2>&1; then
    echo "  [OK] claw-code.codes is reachable"
else
    echo "  [WARN] claw-code.codes may be unreachable from this network"
fi

# Create integration config
cat > /home/ubuntu/proxy-stack/claw-code-config.json << EOF
{
  "endpoint": "https://claw-code.codes",
  "api_version": "v1",
  "auth_type": "bearer",
  "timeout_ms": 300000,
  "retry_policy": {
    "max_retries": 3,
    "backoff_ms": 1000
  },
  "endpoints": {
    "generate": "/api/v1/generate",
    "status": "/api/v1/status",
    "models": "/api/v1/models"
  }
}
EOF

echo ""
echo "=== CLAW-CODE INTEGRATION COMPLETE ==="
echo "Config: /home/ubuntu/proxy-stack/claw-code-config.json"
echo "Token: ${CLAW_CODE_TOKEN:0:8}... (hidden)"
echo ""
echo "API endpoints available:"
echo "  POST https://localhost/api/ai/generate  -> claw-code.codes"
echo "  POST https://localhost/api/code/generate -> opencode -> claw-code.codes"
