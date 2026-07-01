data "docker_registry_image" "radarr" {
  name = "lscr.io/linuxserver/radarr:latest"
}

resource "docker_image" "radarr" {
  name          = data.docker_registry_image.radarr.name
  pull_triggers = [data.docker_registry_image.radarr.sha256_digest]
}

resource "local_file" "radarr_anime_config" {
  filename = abspath("${path.module}/configs/radarr/config.xml")
  content = <<-EOT
  <Config>
    <BindAddress>*</BindAddress>
    <SslPort>6969</SslPort>
    <EnableSsl>False</EnableSsl>
    <LaunchBrowser>True</LaunchBrowser>
    <AuthenticationMethod>External</AuthenticationMethod>
    <AuthenticationRequired>Enabled</AuthenticationRequired>
    <Branch>master</Branch>
    <LogLevel>debug</LogLevel>
    <SslCertPath></SslCertPath>
    <SslCertPassword></SslCertPassword>
    <UrlBase></UrlBase>
    <InstanceName>Prowlarr</InstanceName>
    <UpdateMechanism>Docker</UpdateMechanism>
  </Config>
  EOT
}

resource "docker_container" "radarr_anime" {
  name     = "radarr_anime"
  hostname = "radarr-anime"
  image    = docker_image.radarr.image_id

  restart = "unless-stopped"

  lifecycle {
    replace_triggered_by = [ local_file.radarr_anime_config ]
  }

  volumes {
    host_path      = local_file.radarr_anime_config.filename
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
    label = "traefik.http.routers.radarr_anime.service"
    value = "radarr_anime"
  }

  labels {
    label = "traefik.http.services.radarr_anime.loadbalancer.server.port"
    value = "80"
  }

  labels {
    label = "traefik.http.routers.radarr_anime.rule"
    value = "Host(`${local.radarr_anime_domain}`)"
  }

  labels {
    label = "traefik.http.routers.radarr_anime.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.radarr_anime.entrypoints"
    value = "websecure"
  }


  env = [
    "RADARR__AUTH__APIKEY=${local.api_key}",
    "RADARR__SERVER__PORT=80",
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.radarr_anime_ip
  }
}