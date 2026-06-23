module "router" {
  source = "./router"
  module_subnet = local.router_subnet
  advertise_range = local.ip_range
  network_name = docker_network.tailscale_docker_net.name
  overwrite_tailnet_acl = var.overwrite_tailnet_acl
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

  vaultwarden_backup_dir = "${local.workdir}/vaultwarden/backup/"
  vaultwarden_data_dir = "${local.workdir}/vaultwarden/data/"
  rclone_conf_path = "${local.workdir}/vaultwarden/rclone/rclone.conf"

  vaultwarden_domain = "vaultwarden.${local.docker_suffix}"

  module_subnet = local.vaultwarden_subnet
  network_name = docker_network.tailscale_docker_net.name
}


module "immich" {
  source = "./immich"

  immich_data = "${local.workdir}/immich/"
  module_subnet = local.immich_subnet
  network_name = docker_network.tailscale_docker_net.name
  immich_domain = "immich.${local.docker_suffix}"
}

module "documents" {
  source = "./documents"

  module_subnet = local.documents_subnet
  network_name = docker_network.tailscale_docker_net.name
  
  paperless_domain = "paperless.${local.docker_suffix}"
  paperless_data_dir = "${local.workdir}/paperless/"

  paisa_domain = "paisa.${local.docker_suffix}"
  paisa_data_dir = "${local.workdir}/paisa/"

  stirlingpdf_domain = "pdf.${local.docker_suffix}"
  stirlingpdf_data_dir = "${local.workdir}/stirlingpdf/"
}

module "media" {
  source = "./media"

  module_subnet = local.media_subnet
  network_name = docker_network.tailscale_docker_net.name
  media_dir = "${local.workdir}/media/"
  docker_suffix = local.docker_suffix
}

module "uptime" {
  source = "./uptime"

  module_subnet = local.uptime_subnet
  network_name = docker_network.tailscale_docker_net.name
  gatus_domain = "gatus.${local.docker_suffix}"
  coredns_ip = module.dns.coredns_ip
  traefik_ip = module.dns.traefik_ip
  pihole_ip = module.dns.pihole_ip
  internal_suffix = local.internal_suffix
}

module "tailscale_dns_config" {
  source = "./tailscale-dns"
  dns_ip = module.dns.coredns_ip
  docker_suffix = local.docker_suffix
  internal_suffix = local.internal_suffix

  depends_on = [module.router, module.dns]
}