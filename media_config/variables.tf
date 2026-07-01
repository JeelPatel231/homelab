variable "hosts" {
  type = map(string)
}

variable "api_key" {
  type = string
}

variable "qbit_webui_password" {
  type        = string
  sensitive   = true
}