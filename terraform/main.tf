terraform {
  required_version = ">= 1.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  # Token can be provided via:
  # 1. TF_VAR_do_token environment variable
  # 2. DIGITALOCEAN_TOKEN environment variable (provider default)
  # 3. terraform.tfvars file
  token = var.do_token
}

data "digitalocean_ssh_key" "main" {
  name = var.ssh_key_name
}

resource "digitalocean_droplet" "vpn_exit" {
  name     = var.droplet_name
  region   = var.region
  size     = var.droplet_size
  image    = "ubuntu-24-04-x64"
  ssh_keys = [data.digitalocean_ssh_key.main.id]

  tags = ["vpn", "wireguard", "upnp"]
}

resource "digitalocean_firewall" "vpn_exit" {
  name        = "${var.droplet_name}-firewall"
  droplet_ids = [digitalocean_droplet.vpn_exit.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # WireGuard (UDP)
  inbound_rule {
    protocol         = "udp"
    port_range       = tostring(var.wg_port)
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # wstunnel (TCP) — WebSocket fallback for WireGuard on restrictive networks
  inbound_rule {
    protocol         = "tcp"
    port_range       = tostring(var.wg_port)
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # UPnP mapped ports (high ports for P2P)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "1024-65535"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = "1024-65535"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
