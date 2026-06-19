locals {
  dockerfile = "${path.module}/Dockerfile.fswatch"
  dockerfile_hash = filesha1(local.dockerfile)

  vaultwarden_ip = cidrhost(var.module_subnet, 0)
}

resource "docker_image" "rclone_fswatch_image" {
  name = "rclone_fswatch"
  triggers = {
    dockerfile = local.dockerfile_hash
  }
  build {
    context = "."
    dockerfile = local.dockerfile
  }
}

resource "docker_container" "rclone_fswatch_container" {
  name = "rclone_fswatch"
  image = docker_image.rclone_fswatch_image.image_id

  volumes {
    host_path = var.rclone_conf_path
    container_path = "/rclone.conf"
    read_only = true
  }

  # this container only reads the dir and uploads to gdrive
  volumes {
    host_path = var.vaultwarden_backup_dir
    container_path = "/backup"
    read_only = true
  }

  lifecycle {
    replace_triggered_by = [
      docker_image.rclone_fswatch_image
    ]
  }
}

data "docker_registry_image" "vaultwarden_backup" {
  name = "bruceforce/vaultwarden-backup:2.1.5"
}

resource "docker_image" "vaultwarden_backup" {
  name          = data.docker_registry_image.vaultwarden_backup.name
  pull_triggers = [data.docker_registry_image.vaultwarden_backup.sha256_digest]
}

resource "docker_container" "vaultwarden_backup" {
  name = "vaultwarden_backup"
  image = docker_image.vaultwarden_backup.image_id
  init = true
  env = [
    "BACKUP_ON_STARTUP=true",
    "LOG_LEVEL=DEBUG",
    "TIMESTAMP=true",
    "DELETE_AFTER=10",
    "UID=0",
    "GID=0",
    "TZ=asia/kolkata",
    "BACKUP_DIR=/backup",
    "CRON_TIME=0 0 * * * ", # see https://crontab.guru/, define without quotes!
  ]

  volumes {
    host_path = var.vaultwarden_data_dir
    container_path = "/data/"
  }

  volumes {
    host_path = var.vaultwarden_backup_dir
    container_path = "/backup"
  }

  volumes {
    host_path = "/etc/localtime"
    container_path = "/etc/localtime"
    read_only = true
  }

  volumes {
    host_path = "/etc/timezone"
    container_path = "/etc/timezone"
    read_only = true
  }
}



data "docker_registry_image" "vaultwarden" {
  name = "vaultwarden/server:1.35.4-alpine"
}

resource "docker_image" "vaultwarden" {
  name          = data.docker_registry_image.vaultwarden.name
  pull_triggers = [data.docker_registry_image.vaultwarden.sha256_digest]
}

resource "docker_container" "vaultwarden" {
  name = "vaultwarden"
  hostname = "vaultwarden_server"
  image = docker_image.vaultwarden.image_id

  volumes {
    host_path = var.vaultwarden_data_dir
    container_path = "/data/"
  }

  networks_advanced {
    name = var.network_name
    ipv4_address = local.vaultwarden_ip
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.vaultwarden.rule"
    value = "Host(`${var.vaultwarden_domain}`)"
  }

  labels {
    label = "traefik.http.routers.vaultwarden.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.vaultwarden.entrypoints"
    value = "websecure"
  }

  env = [
    "domain=${var.vaultwarden_domain}"
  ]
}
