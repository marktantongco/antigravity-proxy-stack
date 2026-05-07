#!/bin/bash
# 9router Network Routing Container Setup
# Requires NET_ADMIN capability and TUN device

echo "=== 9ROUTER INTEGRATION ==="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "WARNING: Some operations require root. Run with sudo if errors occur."
fi

# Create TUN device if not exists
if [ ! -c /dev/net/tun ]; then
    echo "Creating TUN device..."
    sudo mkdir -p /dev/net
    sudo mknod /dev/net/tun c 10 200 2>/dev/null || true
    sudo chmod 600 /dev/net/tun
fi

# Verify TUN
if [ -c /dev/net/tun ]; then
    echo "  [OK] TUN device available"
else
    echo "  [FAIL] Cannot create TUN device. Check kernel module:"
    echo "    sudo modprobe tun"
fi

# Enable IP forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null
echo 1 | sudo tee /proc/sys/net/ipv4/conf/all/forwarding > /dev/null

# Load kernel modules
sudo modprobe tun 2>/dev/null || true
sudo modprobe iptable_nat 2>/dev/null || true
sudo modprobe iptable_mangle 2>/dev/null || true

# Docker network for 9router
if ! docker network ls | grep -q "9router-net"; then
    docker network create         --driver bridge         --subnet 172.30.0.0/16         --gateway 172.30.0.1         --opt "com.docker.network.bridge.name"="9router0"         9router-net 2>/dev/null || true
fi

# Standalone 9router (alternative to docker-compose)
echo "Starting 9router container..."
docker run -d     --name 9router-standalone     --network 9router-net     --cap-add NET_ADMIN     --cap-add SYS_MODULE     --sysctl net.ipv4.ip_forward=1     --device /dev/net/tun:/dev/net/tun     -p 8080:8080     -p 9090:9090     -e ROUTER_MODE=proxy     -e UPSTREAM_PROXY="${AG_PROXY_HOST:-127.0.0.1}:${AG_PROXY_PORT:-7890}"     -e PROXY_TYPE="${AG_PROXY_TYPE:-socks5}"     -e LOG_LEVEL=info     --restart unless-stopped     9router:latest 2>/dev/null || echo "9router:latest not found, using docker-compose instead"

echo ""
echo "=== 9ROUTER STATUS ==="
docker ps --filter "name=9router" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No 9router container running"
echo ""
echo "Admin UI: http://localhost:9090"
echo "Proxy:    http://localhost:8080"
