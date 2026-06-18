variable "network_name" {
  type = string
}

variable "advertise_range" {
  type    = string
}

variable "module_subnet" {
  type = string
}

variable "overwrite_tailnet_acl" {
  type = bool
}