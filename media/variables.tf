variable "network_name" {
  type = string
}

variable "docker_suffix" {
  type = string
}

variable "module_subnet" {
  type = string
}

variable "media_dir" {
  type = string
}

variable "api_key" {
  type        = string
  sensitive   = true
}

variable "webui_password" {
  type        = string
  sensitive   = true
}