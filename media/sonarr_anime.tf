data "docker_registry_image" "sonarr" {
  name = "lscr.io/linuxserver/sonarr:latest"
}

resource "docker_image" "sonarr" {
  name          = data.docker_registry_image.sonarr.name
  pull_triggers = [data.docker_registry_image.sonarr.sha256_digest]
}

resource "docker_container" "sonarr_anime" {
  name     = "sonarr_anime"
  hostname = "sonarr_anime"
  image    = docker_image.sonarr.image_id

  restart = "unless-stopped"

  # volumes {
  #   host_path      = local.sonarr_anime_config_dir
  #   container_path = "/config"
  # }
  volumes {
    host_path      = abspath("${path.module}/configs/sonarr/config.xml")
    container_path = "/config/config.xml"
    read_only = true
  }

  volumes {
    host_path      = var.media_dir
    container_path = "/data"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels { 
    label = "traefik.http.routers.sonarr_anime.service"
    value = "sonarr_anime"
  }

  labels {
    label = "traefik.http.services.sonarr_anime.loadbalancer.server.port"
    value = "80"
  }

  labels {
    label = "traefik.http.routers.sonarr_anime.rule"
    value = "Host(`${local.sonarr_anime_domain}`)"
  }

  labels {
    label = "traefik.http.routers.sonarr_anime.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.sonarr_anime.entrypoints"
    value = "websecure"
  }



  env = [
    "SONARR__AUTH__APIKEY=${local.api_key}",
    "SONARR__SERVER__PORT=80",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.sonarr_anime_ip
  }
}