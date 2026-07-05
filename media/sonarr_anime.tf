data "docker_registry_image" "sonarr" {
  name = "lscr.io/linuxserver/sonarr:latest"
}

resource "docker_image" "sonarr" {
  name          = data.docker_registry_image.sonarr.name
  pull_triggers = [data.docker_registry_image.sonarr.sha256_digest]
}

resource "local_file" "sonarr_anime_config" {
  filename = abspath("${path.module}/configs/sonarr/config.xml")
  content = <<-EOT
  <Config>
    <BindAddress>*</BindAddress>
    <SslPort>9898</SslPort>
    <EnableSsl>False</EnableSsl>
    <LaunchBrowser>True</LaunchBrowser>
    <AuthenticationMethod>External</AuthenticationMethod>
    <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
    <Branch>main</Branch>
    <LogLevel>debug</LogLevel>
    <SslCertPath></SslCertPath>
    <SslCertPassword></SslCertPassword>
    <UrlBase></UrlBase>
    <InstanceName>Sonarr</InstanceName>
    <UpdateMechanism>Docker</UpdateMechanism>
  </Config>
  EOT
}



resource "docker_container" "sonarr_anime" {
  name     = "sonarr_anime"
  hostname = "sonarr-anime"
  image    = docker_image.sonarr.image_id

  restart = "unless-stopped"

  # volumes {
  #   host_path      = local.sonarr_anime_config_dir
  #   container_path = "/config"
  # }

  depends_on = [ local_file.media_folders ]

  lifecycle {
    replace_triggered_by = [ local_file.sonarr_anime_config ]
  }

  volumes {
    host_path      = local_file.sonarr_anime_config.filename
    container_path = "/config/config.xml"
    read_only = true
  }

  volumes {
    host_path      = var.media_dir
    container_path = "/data"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels { 
    label = "traefik.http.routers.sonarr_anime.service"
    value = "sonarr_anime"
  }

  labels {
    label = "traefik.http.services.sonarr_anime.loadbalancer.server.port"
    value = "80"
  }

  labels {
    label = "traefik.http.routers.sonarr_anime.rule"
    value = "Host(`${local.sonarr_anime_domain}`)"
  }

  labels {
    label = "traefik.http.routers.sonarr_anime.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.sonarr_anime.entrypoints"
    value = "websecure"
  }



  env = [
    "SONARR__AUTH__APIKEY=${local.api_key}",
    "SONARR__SERVER__PORT=80",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.sonarr_anime_ip
  }
}