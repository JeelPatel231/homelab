locals {
  paperless_broker_ip = cidrhost(var.module_subnet, 2)
  paperless_ip        = cidrhost(var.module_subnet, 3)

  paperless_data_dir = "${var.paperless_data_dir}/data"
  paperless_media_dir = "${var.paperless_data_dir}/media"
  paperless_export_dir = "${var.paperless_data_dir}/export"
  paperless_consume_dir = "${var.paperless_data_dir}/consume"
}

data "docker_registry_image" "paperless_broker" {
  name = "redis:8"
}

resource "docker_image" "paperless_broker" {
  name          = data.docker_registry_image.paperless_broker.name
  pull_triggers = [data.docker_registry_image.paperless_broker.sha256_digest]
}

resource "docker_volume" "broker_data" {
  name = "paperless_broker_data"
}

resource "docker_container" "paperless_broker" {
  name  = "paperless_broker"
  image = docker_image.paperless_broker.image_id

  restart = "unless-stopped"

  volumes {
    volume_name = docker_volume.broker_data.name
    container_path = "/data"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.paperless_broker_ip
  }
}

data "docker_registry_image" "paperless" {
  name = "ghcr.io/paperless-ngx/paperless-ngx:latest"
}

resource "docker_image" "paperless" {
  name          = data.docker_registry_image.paperless.name
  pull_triggers = [data.docker_registry_image.paperless.sha256_digest]
}

resource "docker_container" "paperless" {
  name  = "paperless"
  image = docker_image.paperless.image_id

  restart = "unless-stopped"

  depends_on = [
    docker_container.paperless_broker
  ]

  volumes {
    host_path      = local.paperless_data_dir
    container_path = "/usr/src/paperless/data"
  }

  volumes {
    host_path      = local.paperless_media_dir
    container_path = "/usr/src/paperless/media"
  }

  volumes {
    host_path      = local.paperless_export_dir
    container_path = "/usr/src/paperless/export"
  }

  volumes {
    host_path      = local.paperless_consume_dir
    container_path = "/usr/src/paperless/consume"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.paperless.rule"
    value = "Host(`${var.paperless_domain}`)"
  }

  labels {
    label = "traefik.http.routers.paperless.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.paperless.entrypoints"
    value = "websecure"
  }

  env = [
    "PAPERLESS_REDIS=redis://${docker_container.paperless_broker.hostname}:6379",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.paperless_ip
  }
}