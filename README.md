# VPN Exit Node with UPnP

[Warning: This is AI-generated, and I have not reviewed it throughly. Be careful.]

A Terraform + shell-based deployment for a WireGuard VPN exit node with UPnP support. Designed for scenarios where you need to demo P2P software from networks without port forwarding (hotels, conferences, corporate networks).

When connected, your P2P applications can use UPnP to request port mappings on the VPN server's public IP, making your local services reachable from the internet.

## Architecture

```
┌─────────────────┐         ┌─────────────────────────────────┐
│  Your Machine   │         │  DigitalOcean Droplet           │
│                 │         │                                 │
│  P2P App        │         │  ┌─────────┐    ┌───────────┐  │
│    │            │         │  │WireGuard│    │ miniupnpd │  │
│    ▼            │         │  │  wg0    │◄───│  (UPnP)   │  │
│  UPnP Request ──┼── WG ───┼─►│10.66.66.1    │           │  │
│                 │  Tunnel │  └────┬────┘    └─────┬─────┘  │
│  10.66.66.2     │         │       │               │        │
└─────────────────┘         │       ▼               ▼        │
                            │    ┌─────────────────────┐     │
                            │    │   nftables NAT      │     │
                            │    │   Port Forwarding   │     │
                            │    └──────────┬──────────┘     │
                            │               │                │
                            └───────────────┼────────────────┘
                                            ▼
                                      Public Internet
                                      (your public IP)
```

## Prerequisites

- Terraform >= 1.0
- WireGuard tools (`wireguard-tools` package)
- A DigitalOcean account with API token
- `doctl` CLI (optional, for SSH key management)

## Quick Start

1. **Configure Terraform variables:**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your DO token and SSH key name
   ```

2. **Deploy the infrastructure:**
   ```bash
   terraform init
   terraform apply
   ```

3. **Configure the server:**
   ```bash
   cd ..
   ./scripts/setup-server.sh root@<droplet-ip>
   ```

4. **Set up your local client:**
   ```bash
   ./scripts/setup-client.sh <droplet-ip>
   sudo cp client-config/wg-vpn.conf /etc/wireguard/
   sudo wg-quick up wg-vpn
   ```

5. **Verify UPnP works:**
   ```bash
   upnpc -l
   ```

## Usage

### VPN Control

```bash
# Connect to VPN
sudo wg-quick up wg-vpn

# Disconnect
sudo wg-quick down wg-vpn

# Check status
sudo wg show
```

### UPnP Port Mapping

```bash
# List current mappings
upnpc -l

# Map external port 8080 to local port 8080 (TCP, 1 hour lease)
upnpc -a 10.66.66.2 8080 8080 TCP 3600

# Map UDP port
upnpc -a 10.66.66.2 9000 9000 UDP 3600

# Remove a mapping
upnpc -d 8080 TCP
```

### Verify Setup

```bash
# Check your public IP (should show VPN server IP)
curl -4 ifconfig.me

# Run the test script
./scripts/test-upnp.sh
```

## Project Structure

```
.
├── terraform/
│   ├── main.tf                 # Droplet and firewall resources
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values (IP, SSH command)
│   └── terraform.tfvars        # Your configuration (gitignored)
├── scripts/
│   ├── setup-server.sh         # Server provisioning script
│   ├── setup-client.sh         # Client configuration generator
│   └── test-upnp.sh            # UPnP functionality test
├── keys/                       # SSH and WireGuard keys (gitignored)
├── client-config/              # Generated client configs (gitignored)
└── README.md
```

## Configuration

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `do_token` | DigitalOcean API token | - |
| `ssh_key_name` | Name of SSH key in DO | - |
| `region` | Droplet region | `fra1` |
| `droplet_size` | Droplet size | `s-1vcpu-2gb` |
| `droplet_name` | Droplet name | `vpn-exit-node` |
| `wg_port` | WireGuard port | `51820` |

### Network Configuration

- VPN subnet: `10.66.66.0/24`
- Server VPN IP: `10.66.66.1`
- Client VPN IP: `10.66.66.2`
- WireGuard port: `51820/udp`
- UPnP port range: `1024-65535`

## Teardown

```bash
# Disconnect VPN
sudo wg-quick down wg-vpn

# Destroy infrastructure
cd terraform
terraform destroy
```

## Security Notes

- The firewall allows inbound connections on ports 1024-65535 for UPnP mappings
- UPnP is restricted to clients on the VPN subnet (10.66.66.0/24)
- WireGuard keys are generated locally and the private keys never leave your machine
- Server private key is transmitted once during setup via SSH

## Troubleshooting

**UPnP not working:**
```bash
# Check miniupnpd status on server
ssh root@<server-ip> systemctl status miniupnpd

# Check nftables rules
ssh root@<server-ip> nft list ruleset
```

**VPN connected but no internet:**
```bash
# Check IP forwarding
ssh root@<server-ip> sysctl net.ipv4.ip_forward

# Check NAT rules
ssh root@<server-ip> nft list table inet filter
```

## License

MIT
