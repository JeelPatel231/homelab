terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.29.2"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.4.0"
    }
  }
}

provider "docker" {
  host = local.docker_host
}

provider "tailscale" {
  oauth_client_id      = var.tailscale_client_id
  oauth_client_secret  = var.tailscale_client_secret
  tailnet              = var.tailnet
}