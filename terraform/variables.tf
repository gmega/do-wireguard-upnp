variable "do_token" {
  description = "DigitalOcean API token. Can be set via TF_VAR_do_token or DIGITALOCEAN_TOKEN env var"
  type        = string
  sensitive   = true
  default     = null
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "fra1"
}

variable "droplet_size" {
  description = "Droplet size"
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "droplet_name" {
  description = "Name of the droplet"
  type        = string
  default     = "vpn-exit-node"
}

variable "ssh_key_name" {
  description = "Name of the SSH key in DigitalOcean"
  type        = string
}

variable "wg_port" {
  description = "WireGuard listening port"
  type        = number
  default     = 51820
}
