output "droplet_ip" {
  description = "Public IP address of the VPN exit node"
  value       = digitalocean_droplet.vpn_exit.ipv4_address
}

output "droplet_id" {
  description = "Droplet ID"
  value       = digitalocean_droplet.vpn_exit.id
}

output "ssh_command" {
  description = "SSH command to connect to the droplet"
  value       = "ssh root@${digitalocean_droplet.vpn_exit.ipv4_address}"
}

output "setup_command" {
  description = "Command to run server setup"
  value       = "bash scripts/setup-server.sh root@${digitalocean_droplet.vpn_exit.ipv4_address}"
}
