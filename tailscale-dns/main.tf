resource "tailscale_dns_split_nameservers" "docker_domain_split_dns" {
  domain = var.docker_suffix

  nameservers = [var.dns_ip]
}

resource "tailscale_dns_split_nameservers" "internal_domain_split_dns" {
  domain = var.internal_suffix

  nameservers = [var.dns_ip]
}

resource "tailscale_dns_nameservers" "pihole_dns" {
  nameservers = [
    var.dns_ip
    # "1.1.1.1"
  ]
}