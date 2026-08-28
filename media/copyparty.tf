data "docker_registry_image" "copyparty" {
  name = "copyparty/ac:latest@sha256:a885633e42f7395331ab709c1310bd21e79617b13dfd41c6e3f56910b6a8d2f0"
}

resource "docker_image" "copyparty" {
  name          = data.docker_registry_image.copyparty.name
  pull_triggers = [data.docker_registry_image.copyparty.sha256_digest]
}


// NOTE: many of copyparty's features rely on real ip of client.
// since we are using tailscale router, we may need to update the config of that to preserve the source ip.
// and also forwarded-ip or anything like that
resource "docker_container" "copyparty" {
  name  = "copyparty"
  image = docker_image.copyparty.image_id

  depends_on = [ local_file.media_folder ]

  restart = "unless-stopped"

  volumes {
    host_path = abspath(var.media_dir)
    container_path = "/mnt"
    read_only = true
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.copyparty.rule"
    value = "Host(`${local.copyparty_domain}`)"
  }

  labels {
    label = "traefik.http.routers.copyparty.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.copyparty.entrypoints"
    value = "websecure"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.copyparty_ip
  }

  command = ["-v", "/mnt:/mnt:r"]
}
