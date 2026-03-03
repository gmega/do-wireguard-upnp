#!/bin/bash
set -euo pipefail

# WireGuard Client Setup Script
# Usage: ./setup-client.sh <server-ip>

if [ $# -lt 1 ]; then
    echo "Usage: $0 <server-ip>"
    exit 1
fi

SERVER_IP="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="$SCRIPT_DIR/../keys"
CONFIG_DIR="$SCRIPT_DIR/../client-config"
SSH_KEY="$KEYS_DIR/vpn-exit-node"

echo "==> Setting up WireGuard client for server $SERVER_IP"

# Check for server public key
if [ ! -f "$KEYS_DIR/server_public.key" ]; then
    echo "ERROR: Server public key not found at $KEYS_DIR/server_public.key"
    echo "       Run setup-server.sh first."
    exit 1
fi

SERVER_PUBLIC_KEY=$(cat "$KEYS_DIR/server_public.key")

# Generate client keys if they don't exist
if [ ! -f "$KEYS_DIR/client_private.key" ]; then
    echo "==> Generating WireGuard client keys..."
    mkdir -p "$KEYS_DIR"
    wg genkey | tee "$KEYS_DIR/client_private.key" | wg pubkey > "$KEYS_DIR/client_public.key"
    chmod 600 "$KEYS_DIR/client_private.key"
fi

CLIENT_PRIVATE_KEY=$(cat "$KEYS_DIR/client_private.key")
CLIENT_PUBLIC_KEY=$(cat "$KEYS_DIR/client_public.key")

echo "==> Client public key: $CLIENT_PUBLIC_KEY"

# Create client config directory
mkdir -p "$CONFIG_DIR"

# Generate client config
echo "==> Generating client configuration..."
cat > "$CONFIG_DIR/wg-vpn.conf" << EOF
[Interface]
# Client VPN IP
Address = 10.66.66.2/24
PrivateKey = $CLIENT_PRIVATE_KEY
# Use the VPN's DNS (optional - comment out if you prefer local DNS)
# DNS = 1.1.1.1

[Peer]
# VPN Server
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:443
# Route all traffic through VPN
AllowedIPs = 0.0.0.0/0
# Keep connection alive (important for NAT traversal)
PersistentKeepalive = 25
EOF

echo "==> Adding client peer to server..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "root@$SERVER_IP" bash -s -- "$CLIENT_PUBLIC_KEY" << 'REMOTE_SCRIPT'
set -euo pipefail

CLIENT_PUBLIC_KEY="$1"

# Check if peer already exists
if wg show wg0 peers | grep -q "$CLIENT_PUBLIC_KEY"; then
    echo "    Peer already exists on server"
else
    echo "    Adding peer to server..."
    wg set wg0 peer "$CLIENT_PUBLIC_KEY" allowed-ips 10.66.66.2/32

    # Also add to config file for persistence
    if ! grep -q "$CLIENT_PUBLIC_KEY" /etc/wireguard/wg0.conf; then
        cat >> /etc/wireguard/wg0.conf << EOF

[Peer]
# Client
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 10.66.66.2/32
EOF
    fi
fi

echo "    Server peers:"
wg show wg0 peers
REMOTE_SCRIPT

echo ""
echo "==> Client configuration created!"
echo ""
echo "Configuration file: $CONFIG_DIR/wg-vpn.conf"
echo ""
echo "To activate the VPN:"
echo "  sudo cp $CONFIG_DIR/wg-vpn.conf /etc/wireguard/"
echo "  sudo wg-quick up wg-vpn"
echo ""
echo "To deactivate:"
echo "  sudo wg-quick down wg-vpn"
echo ""
echo "To test UPnP (install miniupnpc first):"
echo "  upnpc -l           # List current mappings"
echo "  upnpc -a 10.66.66.2 8080 8080 TCP 3600  # Map port 8080"
echo ""
echo "To verify your public IP through VPN:"
echo "  curl ifconfig.me"
