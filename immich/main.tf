locals {
  immich_ip = cidrhost(var.module_subnet, 0)
  immich_postgres_ip = cidrhost(var.module_subnet, 1)
  immich_redis_ip = cidrhost(var.module_subnet, 2)
  immich_ml_ip  = cidrhost(var.module_subnet, 3)
}

resource "local_file" "immich_config" {
  filename = "${path.module}/.env"
  content = <<-EOT
    IMMICH_IP="${local.immich_ip}"
    IMMICH_REDIS_IP="${local.immich_redis_ip}"
    IMMICH_POSTGRES_IP="${local.immich_postgres_ip}"
    IMMICH_ML_IP="${local.immich_ml_ip}"

    UPLOAD_LOCATION="${var.immich_data}/upload/"
    DB_DATA_LOCATION="${var.immich_data}/db/"

    DOCKER_NETWORK="${var.network_name}"
  EOT
}

resource "docker_compose" "app" {
  project_name   = "immich-stack"
  remove_orphans = true
  wait           = true
  profiles = ["default"]
  env_files = [
    local_file.immich_config.filename,
  ]
  config_paths = [
    "${path.module}/docker-compose.yml",
    "${path.module}/docker-compose.override.yml",
  ]
}