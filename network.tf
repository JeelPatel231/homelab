locals {
  ip_range = var.base_cidr

  // divide subnet so that each module gets its own logical separation
  router_subnet = cidrsubnet(var.base_cidr, 8, 1) 
  dns_subnet = cidrsubnet(var.base_cidr, 8, 2)
  vaultwarden_subnet = cidrsubnet(var.base_cidr, 8, 3)
  immich_subnet = cidrsubnet(var.base_cidr, 8, 4)
  documents_subnet = cidrsubnet(var.base_cidr, 8, 5)
}

resource "docker_network" "tailscale_docker_net" {
  name   = "tailscale-docker-terraform" # TODO: change the name
  driver = "bridge"

  ipam_config {
    subnet   = var.base_cidr
    ip_range = var.base_cidr
    gateway  = cidrhost(var.base_cidr, 1) // make first ip of the subnet range the gateway ip
  }
}
