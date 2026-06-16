locals {
  coredns_ip = cidrhost(var.module_subnet, 0)
  pihole_ip  = cidrhost(var.module_subnet, 1)
  unbound_ip = cidrhost(var.module_subnet, 2)

  docker_dns_resolver = "127.0.0.11"

  coredns_corefile = <<-EOT
    docker.jeelpa.tel {
      errors
      log
      rewrite name suffix .docker.jeelpa.tel . answer auto
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