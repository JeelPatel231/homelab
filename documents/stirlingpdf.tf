locals {
  stirling_pdf_ip = cidrhost(var.module_subnet, 1)

  training_data_dir    = "${var.stirlingpdf_data_dir}/trainingData"
  extra_configs_dir    = "${var.stirlingpdf_data_dir}/extraConfigs"
  custom_files_dir     = "${var.stirlingpdf_data_dir}/customFiles"
  logs_dir             = "${var.stirlingpdf_data_dir}/logs"
  pipeline_dir         = "${var.stirlingpdf_data_dir}/pipeline"
}

data "docker_registry_image" "stirling_pdf" {
  name = "docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest"
}

resource "docker_image" "stirling_pdf" {
  name          = data.docker_registry_image.stirling_pdf.name
  pull_triggers = [data.docker_registry_image.stirling_pdf.sha256_digest]
}

resource "docker_container" "stirling_pdf" {
  name     = "stirling-pdf"
  hostname = "pdf"
  image    = docker_image.stirling_pdf.image_id

  restart = "unless-stopped"

  volumes {
    host_path      = local.training_data_dir
    container_path = "/usr/share/tessdata"
  }

  volumes {
    host_path      = local.extra_configs_dir
    container_path = "/configs/"
  }

  volumes {
    host_path      = local.custom_files_dir
    container_path = "/customFiles/"
  }

  volumes {
    host_path      = local.logs_dir
    container_path = "/logs/"
  }

  volumes {
    host_path      = local.pipeline_dir
    container_path = "/pipeline/"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.stirlingpdf.rule"
    value = "Host(`${var.stirlingpdf_domain}`)"
  }

  labels {
    label = "traefik.http.routers.stirlingpdf.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.stirlingpdf.entrypoints"
    value = "websecure"
  }

  env = [
    "SECURITY_ENABLELOGIN=false",
    "LANGS=en_US",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.stirling_pdf_ip
  }
}