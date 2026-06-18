resource "tailscale_dns_nameservers" "pihole_dns" {
  nameservers = [
    var.dns_ip
  ]
}