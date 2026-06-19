locals {
  immich_ip = cidrhost(var.module_subnet, 0)
  immich_postgres_ip = cidrhost(var.module_subnet, 1)
  immich_redis_ip = cidrhost(var.module_subnet, 2)
  immich_ml_ip  = cidrhost(var.module_subnet, 3)
}

locals {
  original_compose = "${path.module}/docker-compose.yml"
  compose_overrides = templatefile("${path.module}/docker-compose.override.yml.tftpl", {
    immich_ip      = local.immich_ip
    redis_ip       = local.immich_redis_ip
    postgres_ip    = local.immich_postgres_ip
    docker_network = var.network_name

    additional_volumes = [
      "${var.immich_data}/external_library:/external:ro"
    ]

    server_labels = {
      "traefik.enable" = "true",
      "traefik.http.routers.immich.rule" = "Host(`${var.immich_domain}`)",
      "traefik.http.routers.immich.entrypoints" = "websecure",
      "traefik.http.routers.immich.tls.certResolver" = "porkbun",
    }
  })
}

resource "terraform_data" "config_trigger" {
  input = filesha1(local.original_compose)
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
    local.original_compose,
    local_file.immich_override_config.filename,
  ]

  lifecycle {
    replace_triggered_by = [
      terraform_data.config_trigger,
      local_file.immich_override_config,
      local_file.immich_env_config,
    ]
  }

}