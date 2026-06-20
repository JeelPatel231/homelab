
data "docker_registry_image" "flaresolverr" {
  name = "flaresolverr/flaresolverr:latest"
}

resource "docker_image" "flaresolverr" {
  name          = data.docker_registry_image.flaresolverr.name
  pull_triggers = [data.docker_registry_image.flaresolverr.sha256_digest]
}

resource "docker_container" "flaresolverr" {
  name     = "flaresolverr"
  hostname = "flaresolverr"
  image    = docker_image.flaresolverr.image_id

  env = [
    "LOG_LEVEL=info",
    "LOG_HTML=false",
    "CAPTCHA_SOLVER=none",
  ]

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.flaresolverr.rule"
    value = "Host(`${local.flaresolverr_domain}`)"
  }

  labels {
    label = "traefik.http.routers.flaresolverr.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.flaresolverr.entrypoints"
    value = "websecure"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.flaresolverr_ip
  }
}