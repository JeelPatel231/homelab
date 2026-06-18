locals {
  immich_ip = cidrhost(var.module_subnet, 0)
  immich_postgres_ip = cidrhost(var.module_subnet, 1)
  immich_redis_ip = cidrhost(var.module_subnet, 2)
  immich_ml_ip  = cidrhost(var.module_subnet, 3)
}

locals {
  compose_overrides = templatefile("${path.module}/docker-compose.override.yml.tftpl", {
    immich_ip      = local.immich_ip
    redis_ip       = local.immich_redis_ip
    postgres_ip    = local.immich_postgres_ip
    docker_network = var.network_name

    server_labels = {
      "traefik.enable" = "true",
      "traefik.http.routers.vaultwarden.rule" = "Host(`${var.immich_domain}`)",
      "traefik.http.routers.whoami.entrypoints" = "web",
    }
  })
}

resource "local_file" "immich_override_config" {
  filename = "${path.module}/docker-compose.generated.yml"
  content = local.compose_overrides
}

resource "local_file" "immich_env_config" {
  filename = "${path.module}/.env"
  content = <<-EOT
    UPLOAD_LOCATION="${var.immich_data}/upload/"
    DB_DATA_LOCATION="${var.immich_data}/db/"
  EOT
}

resource "docker_compose" "app" {
  project_name   = "immich-stack"
  remove_orphans = true
  wait           = true
  profiles = ["default"]
  env_files = [
    local_file.immich_env_config.filename,
  ]
  config_paths = [
    "${path.module}/docker-compose.yml",
    local_file.immich_override_config.filename,
  ]
}