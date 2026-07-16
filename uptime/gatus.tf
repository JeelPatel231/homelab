locals {
  gatus_ip = cidrhost(var.module_subnet, 0)
  config_dir = "${path.module}/generated/config/"
  hostname = "gatus"
  docker_dns = "127.0.0.11"
}

resource "local_file" "gatus_config" {
  content  = <<-EOT
    interval: 2m

    storage:
      type: sqlite
      path: /db/data.db

    endpoints:
      # # only needed if the host is outside of tailnet.
      # - name: host-dns-resolution
      #   group: dns
      #   url: ${local.docker_dns}
      #   interval: 5m
      #   dns:
      #     query-name: "one.one.one.one"
      #     query-type: "A"
      #   conditions:
      #     - "[DNS_RCODE] == NOERROR"
      #     - "[BODY] == pat(*.*.*.*)"
      #     - "[RESPONSE_TIME] < 200" 

      - name: docker-dns-resolution
        group: dns
        url: "${var.coredns_ip}"
        interval: 5m
        dns:
          query-name: "gatus.docker.jeelpa.tel"
          query-type: "A"
        conditions:
          - "[DNS_RCODE] == NOERROR"
          - "[BODY] == ${var.traefik_ip}"
          - "[RESPONSE_TIME] < 200" 

      
      - name: internal-dns-resolution
        group: dns
        url: "${var.coredns_ip}"
        interval: 5m
        dns:
          query-name: "${local.hostname}.${var.internal_suffix}"
          query-type: "A"
        conditions:
          - "[DNS_RCODE] == NOERROR"
          - "[BODY] == ${local.gatus_ip}"
          - "[RESPONSE_TIME] < 200" 

      - name: pihole-dns-resolution
        group: dns
        url: ${var.pihole_ip}
        interval: 5m
        dns:
          query-name: "one.one.one.one"
          query-type: "A"
        conditions:
          - "[DNS_RCODE] == NOERROR"
          - "[BODY] == pat(*.*.*.*)"
          - "[RESPONSE_TIME] < 500"

      - name: "Immich"
        group: media
        url: "http://immich:2283/api/server/ping"
        conditions:
          - "[STATUS] == 200"
          - "[BODY].res == pong"
          - "[RESPONSE_TIME] < 100"

      - name: "Prowlarr"
        group: arr
        url: "http://prowlarr/api/v1/health"
        headers:
          X-API-Key: "${var.arr_api_key}"
        conditions:
          - "[STATUS] == 200"
          - "[RESPONSE_TIME] < 100"

      - name: "Sonarr[Anime]"
        group: arr
        url: "http://sonarr-anime/api/v3/health"
        headers:
          X-API-Key: "${var.arr_api_key}"
        conditions:
          - "[STATUS] == 200"
          - "[RESPONSE_TIME] < 100"

      - name: "Radarr [Anime]"
        group: arr
        url: "http://radarr-anime/api/v3/health"
        headers:
          X-API-Key: "${var.arr_api_key}"
        conditions:
          - "[STATUS] == 200"
          - "[RESPONSE_TIME] < 100"

      - name: "FlareSolverr"
        group: arr
        url: "http://flaresolverr/health"
        conditions:
          - "[STATUS] == 200"
          - "[RESPONSE_TIME] < 100"

      - name: "qBittorrent"
        group: arr
        url: "http://qbittorrent/api/v2/app/webapiVersion"
        headers:
          Authorization: "Bearer ${var.arr_api_key}"
        conditions:
          - "[STATUS] == 200"
          - "[RESPONSE_TIME] < 100"
      
  EOT
  filename = abspath("${local.config_dir}/config.yaml")
}

data "docker_registry_image" "gatus" {
  name = "twinproduction/gatus:latest"
}

resource "docker_image" "gatus" {
  name          = data.docker_registry_image.gatus.name
  pull_triggers = [data.docker_registry_image.gatus.sha256_digest]
}

resource "docker_volume" "gatus_data" {
  name = "gatus_data"
}

resource "docker_container" "gatus" {
  name  = "gatus"
  image = docker_image.gatus.image_id
  hostname = local.hostname

  restart = "unless-stopped"
  
  lifecycle {
    replace_triggered_by = [ local_file.gatus_config ]
  }

  volumes {
    host_path      = abspath(local.config_dir)
    container_path = "/config"
    read_only      = true
  }

  volumes {
    volume_name = docker_volume.gatus_data.name
    container_path = "/db/"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.gatus.rule"
    value = "Host(`${var.gatus_domain}`)"
  }

  labels {
    label = "traefik.http.routers.gatus.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.gatus.entrypoints"
    value = "websecure"
  }

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.gatus_ip
  }
}