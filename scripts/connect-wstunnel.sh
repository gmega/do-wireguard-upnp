#!/bin/bash
set -euo pipefail

# Connect to VPN via wstunnel (WebSocket fallback for restrictive networks)
# Usage: sudo ./connect-wstunnel.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../client-config"
CONF="$CONFIG_DIR/wg-vpn-wstunnel.conf"
ENV_FILE="$CONFIG_DIR/wstunnel.env"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root (sudo)."
    exit 1
fi

if [ ! -f "$CONF" ]; then
    echo "ERROR: wstunnel config not found at $CONF"
    echo "       Run setup-client.sh first."
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: wstunnel secret not found at $ENV_FILE"
    echo "       Run setup-server.sh and setup-client.sh first."
    exit 1
fi

# Install config and env file
cp "$CONF" /etc/wireguard/wg-vpn-wstunnel.conf
cp "$ENV_FILE" /etc/wireguard/wstunnel.env
wg-quick up wg-vpn-wstunnel

echo ""
echo "Connected via wstunnel! Verify with:"
echo "  curl -4 ifconfig.me"
echo ""
echo "To disconnect:"
echo "  sudo wg-quick down wg-vpn-wstunnel"
