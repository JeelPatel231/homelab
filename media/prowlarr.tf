data "docker_registry_image" "prowlarr" {
  name = "ghcr.io/hotio/prowlarr:release-2.0.5.5160"
}

resource "docker_image" "prowlarr" {
  name          = data.docker_registry_image.prowlarr.name
  pull_triggers = [data.docker_registry_image.prowlarr.sha256_digest]
}

resource "local_file" "prowlarr_config" {
  filename = abspath("${path.module}/configs/prowlarr/config.xml")
  content  = <<-EOT
  <Config>
    <BindAddress>*</BindAddress>
    <SslPort>6969</SslPort>
    <EnableSsl>False</EnableSsl>
    <LaunchBrowser>True</LaunchBrowser>
    <AuthenticationMethod>External</AuthenticationMethod>
    <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
    <Branch>master</Branch>
    <LogLevel>debug</LogLevel>
    <SslCertPath></SslCertPath>
    <SslCertPassword></SslCertPassword>
    <UrlBase></UrlBase>
    <InstanceName>Prowlarr</InstanceName>
    <UpdateMechanism>Docker</UpdateMechanism>
  </Config>
  EOT
  file_permission = "0777"
}

resource "docker_container" "prowlarr" {
  name     = "prowlarr"
  hostname = "prowlarr"
  image    = docker_image.prowlarr.image_id

  restart = "unless-stopped"

  # volumes {
  #   host_path      = local.prowlarr_data_dir
  #   container_path = "/config"
  # }

  lifecycle {
    replace_triggered_by = [local_file.prowlarr_config]
  }

  volumes {
    host_path      = local_file.prowlarr_config.filename
    container_path = "/config/config.xml"
    read_only      = true
  }

  volumes {
    host_path = abspath("${path.module}/prowlarr_indexers")
    container_path = "/config/Definitions/Custom"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.prowlarr.service"
    value = "prowlarr"
  }

  labels {
    label = "traefik.http.services.prowlarr.loadbalancer.server.port"
    value = "80"
  }

  labels {
    label = "traefik.http.routers.prowlarr.rule"
    value = "Host(`${local.prowlarr_domain}`)"
  }

  labels {
    label = "traefik.http.routers.prowlarr.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.prowlarr.entrypoints"
    value = "websecure"
  }

  env = concat([
    "PROWLARR__AUTH__APIKEY=${local.api_key}",
    "PROWLARR__SERVER__PORT=80",
  ], local.arr_permission)

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.prowlarr_ip
  }
}
