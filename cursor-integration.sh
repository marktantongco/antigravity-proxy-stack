#!/bin/bash
# Cursor IDE Proxy Integration for Linux
# Sets HTTP_PROXY/HTTPS_PROXY environment variables for Cursor

echo "=== CURSOR IDE PROXY SETUP ==="

# Detect shell
SHELL_RC=""
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

# Proxy configuration
PROXY_HOST="${AG_PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${AG_PROXY_PORT:-7890}"
PROXY_TYPE="${AG_PROXY_TYPE:-socks5}"

echo "Configuring proxy: $PROXY_TYPE://$PROXY_HOST:$PROXY_PORT"

# Add to shell RC if not already present
if ! grep -q "AG_PROXY_HOST" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << EOF

# === Cursor IDE / Antigravity Proxy Configuration ===
export AG_PROXY_HOST=$PROXY_HOST
export AG_PROXY_PORT=$PROXY_PORT
export AG_PROXY_TYPE=$PROXY_TYPE
export HTTP_PROXY=http://$PROXY_HOST:$PROXY_PORT
export HTTPS_PROXY=http://$PROXY_HOST:$PROXY_PORT
export ALL_PROXY=$PROXY_TYPE://$PROXY_HOST:$PROXY_PORT
export NO_PROXY=localhost,127.0.0.1,::1,*.local
# === End Proxy Configuration ===
EOF
    echo "Proxy configuration added to $SHELL_RC"
else
    echo "Proxy configuration already exists in $SHELL_RC"
fi

# Also add system-wide for systemd services
sudo mkdir -p /etc/systemd/system/user@.service.d
sudo tee /etc/systemd/system/user@.service.d/proxy.conf > /dev/null << EOF
[Service]
Environment="HTTP_PROXY=http://$PROXY_HOST:$PROXY_PORT"
Environment="HTTPS_PROXY=http://$PROXY_HOST:$PROXY_PORT"
Environment="ALL_PROXY=$PROXY_TYPE://$PROXY_HOST:$PROXY_PORT"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF

sudo systemctl daemon-reload

echo ""
echo "=== CURSOR CONFIGURATION ==="
echo "1. Open Cursor IDE"
echo "2. Go to Settings > Proxy"
echo "3. Set HTTP Proxy: http://$PROXY_HOST:$PROXY_PORT"
echo "4. Set SOCKS Proxy: $PROXY_TYPE://$PROXY_HOST:$PROXY_PORT"
echo "5. Restart Cursor"
echo ""
echo "Or use environment variables:"
echo "  source $SHELL_RC"
echo "  cursor ."
