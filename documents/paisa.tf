locals {
  paisa_ip = cidrhost(var.module_subnet, 0)
}

data "docker_registry_image" "paisa" {
  name = "ananthakumaran/paisa:latest"
}

resource "docker_image" "paisa" {
  name          = data.docker_registry_image.paisa.name
  pull_triggers = [data.docker_registry_image.paisa.sha256_digest]
}

resource "docker_container" "paisa" {
  name  = "paisa"
  image = docker_image.paisa.image_id

  restart = "unless-stopped"

  volumes {
    host_path      = var.paisa_data_dir
    container_path = "/root/Documents/paisa/"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.paisa.rule"
    value = "Host(`${var.paisa_domain}`)"
  }

  labels {
    label = "traefik.http.routers.paisa.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.paisa.entrypoints"
    value = "websecure"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.paisa_ip
  }
}