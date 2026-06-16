module "router" {
  source = "./router"
  module_subnet = local.router_subnet
  advertise_range = local.ip_range
  network_name = docker_network.tailscale_docker_net.name
}

module "dns" {
  source = "./dns"
  module_subnet = local.dns_subnet
  pihole_password = var.pihole_password
  network_name = docker_network.tailscale_docker_net.name
}