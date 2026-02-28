#!/bin/bash
set -euo pipefail

# Test UPnP functionality through the VPN
# Run this after connecting to the VPN with wg-quick up wg-vpn

echo "==> Testing UPnP through VPN"
echo ""

# Check if we're connected to the VPN
if ! ip link show wg-vpn &>/dev/null; then
    echo "ERROR: VPN interface wg-vpn not found"
    echo "       Run: sudo wg-quick up wg-vpn"
    exit 1
fi

# Check if miniupnpc is installed
if ! command -v upnpc &>/dev/null; then
    echo "Installing miniupnpc..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y miniupnpc
    elif command -v pacman &>/dev/null; then
        sudo pacman -S miniupnpc
    elif command -v brew &>/dev/null; then
        brew install miniupnpc
    else
        echo "ERROR: Please install miniupnpc manually"
        exit 1
    fi
fi

echo "==> Current public IP (should be VPN server IP):"
curl -s ifconfig.me
echo ""
echo ""

echo "==> Discovering UPnP devices..."
upnpc -l
echo ""

echo "==> Testing port mapping (TCP 9999 -> 9999)..."
upnpc -a 10.66.66.2 9999 9999 TCP 60
echo ""

echo "==> Verifying mapping..."
upnpc -l | grep 9999 || echo "Mapping not found in list"
echo ""

echo "==> Removing test mapping..."
upnpc -d 9999 TCP
echo ""

echo "==> UPnP test complete!"
echo ""
echo "Your P2P software should now be able to request port mappings via UPnP."
