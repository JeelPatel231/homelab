terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
    tailscale = {
      source  = "tailscale/tailscale"
    }
  }
}