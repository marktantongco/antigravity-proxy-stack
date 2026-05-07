#!/bin/bash
# Proxy Stack Recovery and Diagnostics
# Run this when services fail or after misconfiguration

set -e

echo "=== PROXY STACK RECOVERY ==="
echo "Timestamp: $(date -Iseconds)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Check Docker daemon
echo "[1/7] Checking Docker daemon..."
if ! systemctl is-active --quiet docker; then
    echo "${RED}  Docker not running. Starting...${NC}"
    sudo systemctl start docker
else
    echo "${GREEN}  Docker running${NC}"
fi

# 2. Check container status
echo ""
echo "[2/7] Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -E "9router|nginx|ag-|opencode|billing|redis" || echo "${YELLOW}  No proxy containers found${NC}"

# 3. Restart failed containers
echo ""
echo "[3/7] Restarting failed containers..."
for container in 9router nginx ag-tools-ls ag-manager ag-proxy-ai opencode billing-proxy redis; do
    if ! docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
        echo "  Restarting $container..."
        docker restart "$container" 2>/dev/null || echo "${YELLOW}    $container not found${NC}"
    fi
done

# 4. Port binding verification
echo ""
echo "[4/7] Port bindings:"
for port in 22 80 443 3000 3001 3002 8000 8080 8081 9090 6379; do
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        service=$(ss -tlnp | grep ":$port " | head -1 | awk '{print $7}' | cut -d'"' -f2)
        printf "${GREEN}  [OK]${NC} Port %-5s -> %s\n" "$port" "$service"
    else
        printf "${RED}  [MISSING]${NC} Port %s\n" "$port"
    fi
done

# 5. Log analysis for common failures
echo ""
echo "[5/7] Recent errors:"

# 5a. 9router TUN errors
if docker logs --since 5m 9router 2>/dev/null | grep -qi "tun\|permission\|cap_add"; then
    echo "${RED}  9router: TUN/permission errors detected${NC}"
    echo "    Fix: sudo mknod /dev/net/tun c 10 200 && sudo chmod 600 /dev/net/tun"
fi

# 5b. Nginx upstream errors
if sudo tail -n 50 /var/log/nginx/error.log 2>/dev/null | grep -qi "upstream\|502\|503"; then
    echo "${RED}  Nginx: Upstream errors detected${NC}"
    echo "    Fix: docker compose restart ag-tools-ls ag-proxy-ai"
fi

# 5c. Redis connection errors
if docker logs --since 5m billing-proxy 2>/dev/null | grep -qi "redis\|ECONNREFUSED"; then
    echo "${RED}  Billing: Redis connection failed${NC}"
    echo "    Fix: docker compose restart redis billing-proxy"
fi

# 5d. Rate limiting
if docker logs --since 5m billing-proxy 2>/dev/null | grep -qi "rate limit\|429"; then
    echo "${YELLOW}  Billing: Rate limiting active${NC}"
    echo "    Check: curl http://localhost:8081/api/billing/usage"
fi

# 6. Health check endpoints
echo ""
echo "[6/7] Health checks:"
for endpoint in     "http://localhost:3001/health|AG Tools LS"     "http://localhost:3000/health|AG Manager"     "http://localhost:3002/health|AG Proxy AI"     "http://localhost:8000/health|OpenCode"     "http://localhost:8081/health|Billing"     "http://localhost/health|Nginx"
do
    IFS='|' read -r url name <<< "$endpoint"
    status=$(curl -sf -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$status" = "200" ]; then
        printf "${GREEN}  [OK]${NC} %s\n" "$name"
    else
        printf "${RED}  [FAIL]${NC} %s (HTTP %s)\n" "$name" "$status"
    fi
done

# 7. System resources
echo ""
echo "[7/7] System resources:"
echo "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "  Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "  Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"

# Recovery actions
echo ""
# 6b. Vercel status
echo ""
echo "[6b/7] Vercel integration:"
if [ -n "$VERCEL_AI_GATEWAY_API_KEY" ]; then
    curl -sf http://localhost:8081/api/billing/vercel/status 2>/dev/null | jq . || echo "  Vercel status unavailable"
else
    echo "  Vercel not configured"
fi

echo ""
echo "=== RECOVERY ACTIONS ==="
echo "1. Full restart:    docker compose down && docker compose up -d"
echo "2. View logs:       docker compose logs -f [service]"
echo "3. Reset iptables:  sudo ./iptables-rules.sh"
echo "4. Check nginx:     sudo nginx -t && sudo systemctl reload nginx"
echo "5. Reset Redis:     docker compose exec redis redis-cli FLUSHDB"
echo ""
echo "=== RECOVERY COMPLETE ==="
