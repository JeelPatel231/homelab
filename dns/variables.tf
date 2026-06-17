variable "module_subnet" {
  type = string
}

variable "network_name" {
  type = string
}

variable "pihole_password" {
  sensitive = true
  type = string
}

variable "docker_socket" {
  type = string
}