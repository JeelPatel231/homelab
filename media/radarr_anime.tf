data "docker_registry_image" "radarr" {
  name = "lscr.io/linuxserver/radarr:latest"
}

resource "docker_image" "radarr" {
  name          = data.docker_registry_image.radarr.name
  pull_triggers = [data.docker_registry_image.radarr.sha256_digest]
}

resource "local_file" "radarr_anime_config" {
  filename = abspath("${path.module}/generated/configs/radarr/config.xml")
  content = <<-EOT
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
}

locals {
  radarr_init_scripts_dir = abspath("${path.module}/generated/init/radarr/")
}

resource "local_file" "create_movies_folder" {
  filename = abspath("${local.radarr_init_scripts_dir}/01-create-movies-folder")
  content  = <<-EOT
    #!/bin/bash
    mkdir -p /data/movies
    chown -R 1000:1000 /data/movies
    echo "Created Movies folder!"
  EOT
}

resource "local_file" "radarr_copy_defaults" {
  filename = abspath("${local.radarr_init_scripts_dir}/02-copy-defaults")
  content  = <<-EOT
    #!/bin/bash
    cp /defaults/config.xml /config/
    chown -R 1000:1000 /config/
    echo "Defualts Copied"
  EOT
}

resource "docker_volume" "radarr_config" {
  name = "radarr_anime_config"
}

resource "docker_container" "radarr_anime" {
  name     = "radarr_anime"
  hostname = "radarr-anime"
  image    = docker_image.radarr.image_id

  restart = "unless-stopped"

  depends_on = [ 
    local_file.radarr_anime_config,
    local_file.radarr_copy_defaults,
    local_file.media_folder
  ]

  lifecycle {
    replace_triggered_by = [ 
      local_file.radarr_anime_config,
      local_file.radarr_copy_defaults,
      local_file.media_folder,
    ]
  }

  volumes {
    host_path      = local.radarr_init_scripts_dir
    container_path = "/custom-cont-init.d/"
    # read_only = true
  }

  volumes {
    host_path      = local_file.radarr_anime_config.filename
    container_path = "/defaults/config.xml"
    read_only = true
  }

  volumes {
    volume_name    = docker_volume.radarr_config.name
    container_path = "/config"
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


  env = concat([
    "RADARR__AUTH__APIKEY=${local.api_key}",
    "RADARR__SERVER__PORT=80",
  ], local.arr_permission)

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.radarr_anime_ip
  }
}