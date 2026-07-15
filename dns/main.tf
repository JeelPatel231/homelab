locals {
  coredns_ip = cidrhost(var.module_subnet, 0)
  pihole_ip  = cidrhost(var.module_subnet, 1)
  unbound_ip = cidrhost(var.module_subnet, 2)
  traefik_ip = cidrhost(var.module_subnet, 3)

  docker_dns_resolver = "127.0.0.11"

  // TODO: in match argument in docker_suffix, it uses regex and we should escape the '.' 
}

resource "local_file" "corefile" {
  content = <<-EOT
    ${var.docker_suffix} {
        template IN A {
            answer "{{ .Name }} 60 IN A ${local.traefik_ip}"
        }
    }

    ${var.internal_suffix} {
      errors
      log
      rewrite name suffix .${var.internal_suffix} . answer auto
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
  filename = abspath("${path.module}/Corefile")
}

resource "local_file" "unbound_conf" {
  filename = abspath("${path.module}/generated/unbound.conf")

  content = <<-EOT
    server:
      verbosity: 1
      access-control: 0.0.0.0/0 allow
      interface: 0.0.0.0
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

  volumes {
    host_path = local_file.corefile.filename
    container_path = "/etc/coredns/Corefile"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.coredns_ip
  }
}

resource "docker_container" "unbound" {
  name    = "unbound"
  image   = "alpinelinux/unbound"
  restart = "unless-stopped"

  lifecycle {
    replace_triggered_by = [ local_file.unbound_conf ]
  }

  volumes {
    host_path      = local_file.unbound_conf.filename
    container_path = "/etc/unbound/unbound.conf"
    read_only      = true
  }

  dns = ["1.1.1.1", "8.8.8.8"]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.unbound_ip
  }
}

resource "docker_container" "pihole" {
  name  = "pihole"
  image = "pihole/pihole:latest"
  restart = "unless-stopped"

  env = [
    "FTLCONF_webserver_api_password=${var.pihole_password}",
    "FTLCONF_dns_upstreams=${local.unbound_ip}",
  ]

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels { 
    label = "traefik.http.routers.pihole.service"
    value = "pihole"
  }
 
  labels {
    label = "traefik.http.services.pihole.loadbalancer.server.port"
    value = "80"
  }

  labels {
    label = "traefik.http.routers.pihole.rule"
    value = "Host(`pihole.${var.docker_suffix}`)"
  }

  labels {
    label = "traefik.http.routers.pihole.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.pihole.entrypoints"
    value = "websecure"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.pihole_ip
  }
}


// reverse proxy

locals {
  traefik_config = <<-EOT
  log:
    level: DEBUG

  api:
    insecure: true
    dashboard: true

  entryPoints:
    web:
      address: ":80"
      http:
        redirections:
          entryPoint:
            to: websecure
            scheme: https
            permanent: true

    websecure:
      address: ":443"
      http:
        tls: {}

  providers:
    docker:
      exposedByDefault: false
      network: ${var.network_name}

  certificatesResolvers:
    porkbun:
      acme:
        email: ${var.acme_email}
        storage: /letsencrypt/acme.json
        dnsChallenge:
          provider: porkbun
          # Use specific DNS resolvers to speed up propagation checks
          resolvers:
            - "1.1.1.1:53"
  EOT
}

resource "local_file" "traefik_config" {
  filename        = abspath("${path.module}/generated/traefik.yaml")
  content         = local.traefik_config
  file_permission = "0600"
}

data "docker_registry_image" "traefik" {
  name = "traefik:v3.7.5"
}

resource "docker_image" "traefik" {
  name          = data.docker_registry_image.traefik.name
  pull_triggers = [data.docker_registry_image.traefik.sha256_digest]
}

resource "docker_volume" "traefik_acme" {
  name = "traefik_acme"
}

resource "docker_container" "traefik" {
  name = "traefik"
  image = docker_image.traefik.image_id
  restart = "unless-stopped"

  lifecycle {
    replace_triggered_by = [local_file.traefik_config]
  }

  env = [
    "PORKBUN_API_KEY=${var.porkbun_client_id}",
    "PORKBUN_SECRET_API_KEY=${var.porkbun_client_secret}"
  ]

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.dashboard.rule"
    value = "Host(`${local.dashboard_domain}`)"
  }

  labels {
    label = "traefik.http.routers.dashboard.entrypoints"
    value = "websecure"
  }

  labels {
    label = "traefik.http.routers.dashboard.service"
    value = "api@internal"
  }

  labels {
    label = "traefik.http.routers.dashboard.tls.certResolver"
    value = "porkbun"
  }


  volumes {
    host_path = var.docker_socket
    container_path = "/var/run/docker.sock"
    read_only = true
  }

  volumes {
    host_path =  local_file.traefik_config.filename
    container_path    = "/etc/traefik/traefik.yml"
    read_only = true
  }

  volumes {
    volume_name = docker_volume.traefik_acme.name
    container_path = "/letsencrypt"
  }


  # ports {
  #   internal = 443
  #   external = 9443
  # }

  # ports {
  #   internal = 8080
  #   external = 9080
  # }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.traefik_ip
  }
}
