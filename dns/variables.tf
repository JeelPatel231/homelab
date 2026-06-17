variable "module_subnet" {
  type = string
}

variable "network_name" {
  type = string
}

variable "internal_suffix" {
  type = string
}

variable "docker_suffix" {
  type = string
}

locals {
  dashboard_domain = "dashboard.${var.docker_suffix}"
}

variable "pihole_password" {
  sensitive = true
  type = string
}

variable "porkbun_client_id" {
  type = string
  sensitive = true
}

variable "porkbun_client_secret" {
  type = string
  sensitive = true
}

variable "acme_email" {
  type = string
}

variable "docker_socket" {
  type = string
}