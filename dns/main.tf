locals {
  coredns_ip = cidrhost(var.module_subnet, 0)
  pihole_ip  = cidrhost(var.module_subnet, 1)
  unbound_ip = cidrhost(var.module_subnet, 2)
  traefik_ip = cidrhost(var.module_subnet, 3)

  docker_dns_resolver = "127.0.0.11"

  coredns_corefile = <<-EOT
    docker.jeelpa.tel {
        template IN A {
            match ".*\\.docker\\.jeelpa\\.tel$"
            answer "{{ .Name }} 60 IN A ${local.traefik_ip}"
            fallthrough
        }
    }

    internal.jeelpa.tel {
      errors
      log
      rewrite name suffix .internal.jeelpa.tel . answer auto
      forward . ${local.docker_dns_resolver}

      cache
    }

    . {
      errors
      cancel
      log

      forward . ${local.pihole_ip}
    }
  EOT
}


resource "docker_container" "coredns" {
  name    = "coredns"
  image   = "coredns/coredns"
  restart = "always"

  command = [
    "-conf",
    "/etc/coredns/Corefile",
    "-dns.port",
    "53",
  ]

  upload {
    content = local.coredns_corefile
    file    = "/etc/coredns/Corefile"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.coredns_ip
  }
}

resource "docker_container" "unbound" {
  name    = "unbound"
  image   = "klutchell/unbound"
  restart = "unless-stopped"

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.unbound_ip
  }
}

resource "docker_container" "pihole" {
  name  = "pihole"
  image = "pihole/pihole:latest"

  env = [
    "FTLCONF_webserver_api_password=${var.pihole_password}",
    "FTLCONF_dns_upstreams=${docker_container.unbound.hostname}",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.pihole_ip
  }
}


// reverse proxy

data "docker_registry_image" "traefik" {
  name = "traefik:v3.7.5"
}

resource "docker_image" "traefik" {
  name          = data.docker_registry_image.traefik.name
  pull_triggers = [data.docker_registry_image.traefik.sha256_digest]
}

resource "docker_container" "traefik" {
  name = "traefik"
  image = docker_image.traefik.image_id

  volumes { 
    host_path = var.docker_socket
    container_path = "/var/run/docker.sock"
    read_only = true
  }

  command = [
      "--api.insecure=true",
      "--providers.docker=true",
      "--providers.docker.exposedbydefault=false",
      "--entrypoints.web.address=:80",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.traefik_ip
  }
}
