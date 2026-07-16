locals {
  ip_range = var.base_cidr

  // divide subnet so that each module gets its own logical separation
  router_subnet = cidrsubnet(var.base_cidr, 8, 1) 
  dns_subnet = cidrsubnet(var.base_cidr, 8, 2)
  vaultwarden_subnet = cidrsubnet(var.base_cidr, 8, 3)
  immich_subnet = cidrsubnet(var.base_cidr, 8, 4)
  documents_subnet = cidrsubnet(var.base_cidr, 8, 5)
  media_subnet = cidrsubnet(var.base_cidr, 8, 6) 
  uptime_subnet = cidrsubnet(var.base_cidr, 8, 7)
}


data "docker_network" "tailscale_docker_net" {
  name = "tailscale-docker-terraform"
}
