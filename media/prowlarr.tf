data "docker_registry_image" "prowlarr" {
  name = "ghcr.io/hotio/prowlarr:release-2.0.5.5160"
}

resource "docker_image" "prowlarr" {
  name          = data.docker_registry_image.prowlarr.name
  pull_triggers = [data.docker_registry_image.prowlarr.sha256_digest]
}

resource "docker_container" "prowlarr" {
  name     = "prowlarr"
  hostname = "prowlarr"
  image    = docker_image.prowlarr.image_id

  restart = "unless-stopped"

  # volumes {
  #   host_path      = local.prowlarr_data_dir
  #   container_path = "/config"
  # }
  volumes {
    host_path      = abspath("${path.module}/configs/prowlarr/config.xml")
    container_path = "/config/config.xml"
    read_only = true
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels { 
    label = "traefik.http.routers.prowlarr.service"
    value = "prowlarr"
  }
 
  labels {
    label = "traefik.http.services.prowlarr.loadbalancer.server.port"
    value = "80"
  }

  labels {
    label = "traefik.http.routers.prowlarr.rule"
    value = "Host(`${local.prowlarr_domain}`)"
  }

  labels {
    label = "traefik.http.routers.prowlarr.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.prowlarr.entrypoints"
    value = "websecure"
  }

  env = [
    "PROWLARR__AUTH__APIKEY=${local.api_key}",
    "PROWLARR__SERVER__PORT=80",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.prowlarr_ip
  }
}