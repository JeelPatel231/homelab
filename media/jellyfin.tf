data "docker_registry_image" "jellyfin" {
  name = "lscr.io/linuxserver/jellyfin:latest"
}

resource "docker_image" "jellyfin" {
  name          = data.docker_registry_image.jellyfin.name
  pull_triggers = [data.docker_registry_image.jellyfin.sha256_digest]
}

locals {
  jellyfin_config_dir = abspath("${var.media_dir}/jellyfin_config")
}

resource "docker_container" "jellyfin" {
  name     = "jellyfin"
  hostname = "jellyfin"
  image    = docker_image.jellyfin.image_id

  restart = "unless-stopped"

  depends_on = [local_file.media_folder]

  volumes {
    host_path      = local.jellyfin_config_dir
    container_path = "/config"
  }

  volumes {
    host_path      = var.media_dir
    container_path = "/data"
    read_only      = true
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  # labels {
  #   label = "traefik.http.routers.jellyfin.service"
  #   value = "jellyfin"
  # }

  # labels {
  #   label = "traefik.http.services.jellyfin.loadbalancer.server.port"
  #   value = "8096"
  # }

  labels {
    label = "traefik.http.routers.jellyfin.rule"
    value = "Host(`${local.jellyfin_domain}`)"
  }

  labels {
    label = "traefik.http.routers.jellyfin.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.jellyfin.entrypoints"
    value = "websecure"
  }

  env = local.arr_permission

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.jellyfin_ip
  }
}
