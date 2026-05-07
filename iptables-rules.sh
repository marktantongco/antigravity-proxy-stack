#!/bin/bash
# Run as root: sudo ./iptables-rules.sh
# Assumption: eth0 is primary interface

set -e

IFACE="${IFACE:-eth0}"
DOCKER_SUBNET="${DOCKER_SUBNET:-172.20.0.0/16}"

echo "=== IPTABLES RULES FOR PROXY STACK ==="
echo "Interface: $IFACE"
echo "Docker subnet: $DOCKER_SUBNET"

# Save current rules (backup)
iptables-save > /tmp/iptables-backup-$(date +%Y%m%d-%H%M%S).rules 2>/dev/null || true

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# Default policies: drop everything except established and output
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow established and related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow ICMP (ping)
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT

# Allow SSH (rate limited)
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT

# Allow proxy stack ports
iptables -A INPUT -p tcp --dport 3000 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 3001 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 3002 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 8000 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 8081 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 9090 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 6379 -s 172.20.0.0/16 -m conntrack --ctstate NEW -j ACCEPT

# Docker networking
iptables -A FORWARD -i docker0 -o $IFACE -j ACCEPT
iptables -A FORWARD -i $IFACE -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# NAT for Docker containers
iptables -t nat -A POSTROUTING -s $DOCKER_SUBNET ! -o docker0 -j MASQUERADE

# Anti-spoofing
iptables -A INPUT -s 10.0.0.0/8 -i $IFACE -j DROP
iptables -A INPUT -s 172.16.0.0/12 -i $IFACE -j DROP
iptables -A INPUT -s 192.168.0.0/16 -i $IFACE -j DROP

# Log and drop invalid packets
iptables -A INPUT -m conntrack --ctstate INVALID -j LOG --log-prefix "INVALID_DROP: " --log-level 4
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# Save rules
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# Enable iptables-persistent
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
fi

echo "=== IPTABLES RULES APPLIED ==="
iptables -L -n -v --line-numbers
