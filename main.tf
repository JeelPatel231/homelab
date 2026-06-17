module "router" {
  source = "./router"
  module_subnet = local.router_subnet
  advertise_range = local.ip_range
  network_name = docker_network.tailscale_docker_net.name
}

module "dns" {
  source = "./dns"
  module_subnet = local.dns_subnet
  docker_socket = var.docker_socket
  pihole_password = var.pihole_password
  porkbun_client_id = var.porkbun_client_id
  porkbun_client_secret = var.porkbun_client_secret
  acme_email = var.acme_email
  internal_suffix = local.internal_suffix
  docker_suffix = local.docker_suffix
  network_name = docker_network.tailscale_docker_net.name
}

module "vaultwarden" {
  source = "./vaultwarden"
  rclone_conf_path = "/home/jeel/.config/rclone/rclone.conf"
  vaultwarden_backup_dir = "/tmp"
  vaultwarden_data_dir = "${local.workdir}/vaultwarden/data/"

  vaultwarden_domain = "vaultwarden.${local.docker_suffix}"

  module_subnet = local.vaultwarden_subnet
  network_name = docker_network.tailscale_docker_net.name
}

module "tailscale_dns_config" {
  source = "./tailscale-dns"
  pihole_ip = module.dns.pihole_ip
  depends_on = [module.router, module.dns]
}