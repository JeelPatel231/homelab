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
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "3.4.2"
    }
    radarr = {
      source  = "devopsarr/radarr"
      version = "2.3.5"
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

provider "sonarr" {
  // hardcoded for now.
  url     = "http://sonarr-anime.${local.internal_suffix}"
  api_key = var.arr_api_key
}

provider "radarr" {
  // hardcoded for now.
  url     = "http://radarr-anime.${local.internal_suffix}"
  api_key = var.arr_api_key
}