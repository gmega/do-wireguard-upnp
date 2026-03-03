#!/bin/bash
set -euo pipefail

# VPN Exit Node Setup Script
# Usage: ./setup-server.sh root@<server-ip>

if [ $# -lt 1 ]; then
    echo "Usage: $0 <user@server-ip>"
    exit 1
fi

SERVER="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_KEY="$SCRIPT_DIR/../keys/vpn-exit-node"

echo "==> Setting up VPN exit node on $SERVER"

# Generate server keys locally if they don't exist
if [ ! -f "$SCRIPT_DIR/../keys/server_private.key" ]; then
    echo "==> Generating WireGuard server keys..."
    mkdir -p "$SCRIPT_DIR/../keys"
    wg genkey | tee "$SCRIPT_DIR/../keys/server_private.key" | wg pubkey > "$SCRIPT_DIR/../keys/server_public.key"
    chmod 600 "$SCRIPT_DIR/../keys/server_private.key"
fi

SERVER_PRIVATE_KEY=$(cat "$SCRIPT_DIR/../keys/server_private.key")
SERVER_PUBLIC_KEY=$(cat "$SCRIPT_DIR/../keys/server_public.key")

echo "==> Server public key: $SERVER_PUBLIC_KEY"

# Run setup on remote server
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$SERVER" bash -s -- "$SERVER_PRIVATE_KEY" << 'REMOTE_SCRIPT'
set -euo pipefail

SERVER_PRIVATE_KEY="$1"

echo "==> Updating system..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

echo "==> Installing WireGuard and miniupnpd..."
apt-get install -y wireguard miniupnpd nftables

echo "==> Enabling IP forwarding..."
cat > /etc/sysctl.d/99-wireguard.conf << EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl --system

echo "==> Detecting public interface..."
PUBLIC_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
PUBLIC_IP=$(ip -4 addr show "$PUBLIC_IF" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
echo "    Public interface: $PUBLIC_IF"
echo "    Public IP: $PUBLIC_IP"

echo "==> Configuring WireGuard..."
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.66.66.1/24
ListenPort = 443
PrivateKey = $SERVER_PRIVATE_KEY

# Client peer will be added by add-client script
EOF

chmod 600 /etc/wireguard/wg0.conf

echo "==> Configuring miniupnpd..."
cat > /etc/miniupnpd/miniupnpd.conf << EOF
# MiniUPnPd configuration for VPN exit node

# External interface (public internet)
ext_ifname=$PUBLIC_IF

# Internal interface (WireGuard VPN) - must use IP address
listening_ip=10.66.66.1

# Port for UPnP
port=5000

# Enable NAT-PMP (for macOS/iOS compatibility)
enable_natpmp=yes

# Allow UPnP from VPN clients
allow 1024-65535 10.66.66.0/24 1024-65535
deny 0-65535 0.0.0.0/0 0-65535

# UUID for this device
uuid=12345678-1234-1234-1234-123456789abc

# Presentation URL
presentation_url=http://$PUBLIC_IP:5000/

# Secure mode - require matching source for delete
secure_mode=yes

# System uptime instead of daemon uptime
system_uptime=yes

# Clean up rules on shutdown
clean_ruleset_threshold=20
clean_ruleset_interval=600
EOF

# Create systemd override to ensure miniupnpd starts after wireguard
mkdir -p /etc/systemd/system/miniupnpd.service.d
cat > /etc/systemd/system/miniupnpd.service.d/override.conf << EOF
[Unit]
After=wg-quick@wg0.service nftables.service
Wants=wg-quick@wg0.service

[Service]
ExecStartPre=/bin/sleep 2
Restart=on-failure
RestartSec=5
EOF

echo "==> Starting WireGuard..."
systemctl daemon-reload
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Wait for wg0 to come up
sleep 2

echo "==> Setting up nftables for miniupnpd..."
# Initialize miniupnpd nftables structure
bash /etc/miniupnpd/nft_init.sh

# Add rules for WireGuard traffic forwarding (before the drop policy)
nft add rule inet filter forward iifname "wg0" accept
nft add rule inet filter forward oifname "wg0" ct state related,established accept

# Add masquerade for outgoing traffic
nft add rule inet filter postrouting oifname "$PUBLIC_IF" masquerade

# Save nftables rules
nft list ruleset > /etc/nftables.conf
systemctl enable nftables

echo "==> Enabling miniupnpd..."
systemctl enable miniupnpd
systemctl restart miniupnpd

echo "==> Verifying setup..."
echo ""
echo "WireGuard status:"
wg show
echo ""
echo "miniupnpd status:"
systemctl status miniupnpd --no-pager || true
echo ""
echo "nftables rules:"
nft list table inet filter
echo ""
echo "Listening ports:"
ss -ulnp | grep -E '(443|5000)' || echo "Ports not yet listening"
echo ""
echo "==> Server setup complete!"
echo "    Server public key is displayed above."
echo "    Run the client setup script next."
REMOTE_SCRIPT

echo ""
echo "==> Server setup completed!"
echo "    Server public key: $SERVER_PUBLIC_KEY"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/setup-client.sh <server-ip>"
echo "  2. Activate VPN: sudo wg-quick up wg-vpn"
echo "  3. Test UPnP: upnpc -l"
