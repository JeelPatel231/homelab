locals {
  gatus_ip = cidrhost(var.module_subnet, 0)
  config_dir = "${path.module}/config/"
}

resource "local_file" "gatus_config" {
  content  = <<-EOT
    interval: 2m

    storage:
      type: sqlite
      path: /db/data.db

    endpoints:
      - name: "Immich"
        url: "http://immich:2283/api/server/ping"
        conditions:
          - "[STATUS] == 200"
          - "[BODY].res == pong"
          - "[RESPONSE_TIME] < 100"
  EOT
  filename = abspath("${local.config_dir}/config.yaml")
}

data "docker_registry_image" "gatus" {
  name = "twinproduction/gatus:latest"
}

resource "docker_image" "gatus" {
  name          = data.docker_registry_image.gatus.name
  pull_triggers = [data.docker_registry_image.gatus.sha256_digest]
}

resource "docker_volume" "gatus_data" {
  name = "gatus_data"
}

resource "docker_container" "gatus" {
  name  = "gatus"
  image = docker_image.gatus.image_id

  restart = "unless-stopped"
  
  lifecycle {
    replace_triggered_by = [ local_file.gatus_config ]
  }

  volumes {
    host_path      = abspath(local.config_dir)
    container_path = "/config"
    read_only      = true
  }

  volumes {
    volume_name = docker_volume.gatus_data.name
    container_path = "/db/"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.gatus.rule"
    value = "Host(`${var.gatus_domain}`)"
  }

  labels {
    label = "traefik.http.routers.gatus.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.gatus.entrypoints"
    value = "websecure"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.gatus_ip
  }
}