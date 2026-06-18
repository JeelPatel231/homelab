variable "workdir" {
  type    = string
  default = "./workdir"
}

locals {
  workdir = abspath(var.workdir)
}

variable "tailscale_client_id" {
  type = string
}

variable "tailscale_client_secret" {
  type = string
  sensitive = true
}

variable "tailnet" {
  type = string
  default = null
}

variable "base_cidr" {
  default = "10.110.0.0/16"
}

variable "docker_socket" {
  type = string
  default = "/var/run/docker.sock"
}

// this is for auto generating subdomains for .internal and .docker
variable "root_domain" {
  type = string
}

locals {
  docker_suffix = "docker.${var.root_domain}" // used with traefik
  internal_suffix = "internal.${var.root_domain}" // used with coredns to directly point to container
}

variable "porkbun_client_id" {
  type = string
}

variable "porkbun_client_secret" {
  type = string
}

variable "acme_email" {
  type = string
}

locals {
  docker_host = "unix://${var.docker_socket}"
}


# auto generatable
variable "pihole_password" {
  type = string
  sensitive = true
  default = "Password@1"
}

variable "overwrite_tailnet_acl" {
  type = bool
  default = false
}