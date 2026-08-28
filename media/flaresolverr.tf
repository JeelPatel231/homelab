
data "docker_registry_image" "flaresolverr" {
  name = "flaresolverr/flaresolverr:latest@sha256:139dfee1c6f89249c8d665d1333a42e8ec74ec0a86bc6bb1c8461e10d3a66a47"
}

resource "docker_image" "flaresolverr" {
  name          = data.docker_registry_image.flaresolverr.name
  pull_triggers = [data.docker_registry_image.flaresolverr.sha256_digest]
}

resource "docker_container" "flaresolverr" {
  name     = "flaresolverr"
  hostname = "flaresolverr"
  image    = docker_image.flaresolverr.image_id
  restart = "unless-stopped"

  env = [
    "LOG_LEVEL=info",
    "LOG_HTML=false",
    "CAPTCHA_SOLVER=none",
    "PORT=80",
  ]

  labels {
    label = "traefik.enable"
    value = "true"
  }

  # TODO: add label to let traefik know its running on 80 and not the default exposed port

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