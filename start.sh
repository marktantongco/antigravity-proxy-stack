#!/bin/bash
set -euo pipefail

echo "=== PROXY STACK BOOTSTRAP ==="
echo "Target: Ubuntu 24.04 minimal server"
echo "Assumptions: Docker installed, user in docker group, sudo access"
echo ""

# Verify Ubuntu version
if ! grep -q "Ubuntu 24.04" /etc/os-release 2>/dev/null; then
    echo "WARNING: Not Ubuntu 24.04. Proceeding anyway."
fi

# 1. System prep
echo "[1/8] Configuring kernel parameters..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.forwarding=1
sudo sysctl -w net.ipv4.conf.default.forwarding=1
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi

# 2. Install dependencies
echo "[2/8] Installing dependencies..."
sudo apt-get update
sudo apt-get install -y --no-install-recommends     curl wget git openssl     iptables-persistent     net-tools     jq

# 3. Docker verification
echo "[3/8] Verifying Docker..."
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not found. Install first:"
    echo "  curl -fsSL https://get.docker.com | sh"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "ERROR: Docker Compose v2 not found."
    exit 1
fi

# 4. Firewall setup
echo "[4/8] Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 3000/tcp comment 'AG Manager'
sudo ufw allow 3001/tcp comment 'AG Tools LS'
sudo ufw allow 3002/tcp comment 'AG Proxy AI'
sudo ufw allow 8000/tcp comment 'OpenCode'
sudo ufw allow 8080/tcp comment '9router'
sudo ufw allow 8081/tcp comment 'Billing Proxy'
sudo ufw allow 9090/tcp comment '9router Admin'
sudo ufw allow 6379/tcp comment 'Redis'
sudo ufw --force enable

# 5. Directory structure
echo "[5/8] Creating directory structure..."
mkdir -p /home/ubuntu/proxy-stack/{nginx/ssl,ag-tools-ls,ag-proxy-ai,billing-proxy}
cd /home/ubuntu/proxy-stack

# 6. SSL certificates
echo "[6/8] Generating self-signed SSL certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048     -keyout /home/ubuntu/proxy-stack/nginx/ssl/key.pem     -out /home/ubuntu/proxy-stack/nginx/ssl/cert.pem     -subj "/C=US/ST=State/L=City/O=AntigravityProxy/CN=localhost"     -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:0.0.0.0"

echo "WARNING: Using self-signed certificate. Replace with real cert for production."

# 7. Environment setup
echo "[7/8] Setting up environment..."
if [ ! -f .env ]; then
    echo "ERROR: .env file not found. Create it from .env.example"
    exit 1
fi

# Source env for current session
set -a
source .env
set +a

# 8. Build and start
echo "[8/8] Building and starting services..."
docker compose down 2>/dev/null || true
docker compose build --no-cache
docker compose up -d

# Wait for services
echo "Waiting for services to start..."
sleep 10

# Health checks
echo ""
echo "=== HEALTH CHECKS ==="
for endpoint in     "http://localhost:3001/health|AG Tools LS"     "http://localhost:3000/health|AG Manager"     "http://localhost:3002/health|AG Proxy AI"     "http://localhost:8000/health|OpenCode"     "http://localhost:8081/health|Billing Proxy"     "http://localhost/health|Nginx"
do
    IFS='|' read -r url name <<< "$endpoint"
    if curl -sf "$url" > /dev/null 2>&1; then
        echo "  [OK] $name"
    else
        echo "  [FAIL] $name - check logs: docker compose logs $name"
    fi
done

echo ""
# 7. Vercel integration
echo ""
echo "[7/8] Vercel AI Gateway..."
if [ -n "$VERCEL_AI_GATEWAY_API_KEY" ]; then
    if ./vercel-integration.sh > /dev/null 2>&1; then
        echo "  [OK] Vercel AI Gateway configured"
    else
        echo "  [WARN] Vercel AI Gateway check failed"
    fi
else
    echo "  [SKIP] VERCEL_AI_GATEWAY_API_KEY not set"
fi

echo ""
echo "=== STACK ONLINE ==="
echo "Nginx:      https://localhost (80/443)"
echo "9router:    http://localhost:8080"
echo "AG Tools:   http://localhost:3001"
echo "AG Manager: http://localhost:3000"
echo "AG Proxy:   http://localhost:3002"
echo "OpenCode:   http://localhost:8000"
echo "Billing:    http://localhost:8081"
echo "Redis:      localhost:6379"
echo ""
echo "Install systemd service:"
echo "  sudo cp proxy-stack.service /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now proxy-stack"
