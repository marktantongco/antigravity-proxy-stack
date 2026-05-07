#!/bin/bash
# Vercel AI Gateway Integration Setup
# Configures Vercel AI Gateway as primary AI provider endpoint

echo "=== VERCEL AI GATEWAY INTEGRATION ==="

# Check if tokens are set
if [ -z "$VERCEL_AI_GATEWAY_API_KEY" ]; then
    echo "ERROR: VERCEL_AI_GATEWAY_API_KEY not set"
    echo "Set it: export VERCEL_AI_GATEWAY_API_KEY=vck_..."
    exit 1
fi

# Test Vercel AI Gateway connectivity
echo "Testing Vercel AI Gateway..."
if curl -sf -o /dev/null -w "%{http_code}"     -H "Authorization: Bearer $VERCEL_AI_GATEWAY_API_KEY"     https://ai-gateway.vercel.sh/v1/models 2>/dev/null | grep -q "200"; then
    echo "  [OK] Vercel AI Gateway is reachable"
else
    echo "  [WARN] Vercel AI Gateway may be unreachable or key invalid"
fi

# Test Vercel platform token
if [ -n "$VERCEL_TOKEN" ]; then
    echo "Testing Vercel platform API..."
    if curl -sf -o /dev/null -w "%{http_code}"         -H "Authorization: Bearer $VERCEL_TOKEN"         https://api.vercel.com/v9/user 2>/dev/null | grep -q "200"; then
        echo "  [OK] Vercel platform token valid"
    else
        echo "  [WARN] Vercel platform token may be invalid"
    fi
fi

# Create Vercel config
cat > /home/ubuntu/proxy-stack/vercel-config.json << 'EOF'
{
  "aiGateway": {
    "enabled": true,
    "endpoint": "https://ai-gateway.vercel.sh/v1",
    "providers": ["openai", "anthropic", "google"],
    "rateLimit": {
      "requestsPerMinute": 60,
      "tokensPerDay": 1000000
    },
    "caching": {
      "enabled": true,
      "ttl": 3600
    }
  },
  "fallback": {
    "enabled": true,
    "directProviders": {
      "openai": "https://api.openai.com/v1",
      "anthropic": "https://api.anthropic.com/v1",
      "google": "https://generativelanguage.googleapis.com/v1beta"
    }
  }
}
EOF

# Add to systemd environment
sudo mkdir -p /etc/systemd/system/proxy-stack.service.d
sudo tee /etc/systemd/system/proxy-stack.service.d/vercel.conf > /dev/null << EOF
[Service]
Environment="VERCEL_AI_GATEWAY_API_KEY=$VERCEL_AI_GATEWAY_API_KEY"
Environment="VERCEL_AI_GATEWAY_URL=${VERCEL_AI_GATEWAY_URL:-https://ai-gateway.vercel.sh/v1}"
Environment="VERCEL_TOKEN=${VERCEL_TOKEN:-}"
EOF

sudo systemctl daemon-reload

echo ""
echo "=== VERCEL INTEGRATION COMPLETE ==="
echo "Config: /home/ubuntu/proxy-stack/vercel-config.json"
echo ""
echo "API endpoints:"
echo "  POST https://localhost/api/ai/chat/completions  -> Vercel AI Gateway"
echo "  POST https://localhost/api/ai/gateway/*           -> Vercel direct passthrough"
echo "  GET  https://localhost/api/billing/vercel/status  -> Vercel connection status"
echo ""
echo "Models available through Vercel Gateway:"
echo "  - gpt-4, gpt-4-turbo (OpenAI)"
echo "  - claude-3-5-sonnet, claude-3-opus (Anthropic)"
echo "  - gemini-pro, gemini-ultra (Google)"
