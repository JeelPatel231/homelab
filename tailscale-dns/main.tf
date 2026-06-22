resource "tailscale_dns_split_nameservers" "docker_domain_split_dns" {
  domain = var.docker_suffix

  nameservers = [var.dns_ip]
}

resource "tailscale_dns_nameservers" "pihole_dns" {
  count = 0
  nameservers = [
    var.dns_ip
  ]
}