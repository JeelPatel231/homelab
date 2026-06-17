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

locals {
  docker_host = "unix://${var.docker_socket}"
}


# auto generatable
variable "pihole_password" {
  type = string
  sensitive = true
  default = "Password@1"
}