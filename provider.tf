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
    prowlarr = {
      source  = "devopsarr/prowlarr"
      version = "3.2.1"
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
  url     = "http://sonarr_anime"
  api_key = var.arr_api_key
}

provider "radarr" {
  // hardcoded for now.
  url     = "http://radarr_anime"
  api_key = var.arr_api_key
}

provider "prowlarr" {
  // hardcoded for now.
  url     = "http://prowlarr"
  api_key = var.arr_api_key
}
