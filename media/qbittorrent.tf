data "docker_registry_image" "qbittorrent" {
  name = "lscr.io/linuxserver/qbittorrent:latest"
}

resource "docker_image" "qbittorrent" {
  name          = data.docker_registry_image.qbittorrent.name
  pull_triggers = [data.docker_registry_image.qbittorrent.sha256_digest]
}

locals {
  torrents_dir = "${var.media_dir}/torrents"
}

resource "local_file" "torrents_dir" {
  for_each = toset(local.folders)
  filename = "${local.torrents_dir}/${each.value}/.keep"
  directory_permission = "0777"
  content = ""
}

# 1. External data source that spawns an inline Python Docker container
data "external" "pbkdf2_generator" {
  program = [
    "docker",
    "run",
    "--rm",
    "-i", # Interactive flag allows Docker to forward Terraform's stdin to Python
    "python:3.11-slim",
    "python",
    "-c",
    <<-EOT
import sys, json, os, hashlib, base64
try:
    inputs = json.load(sys.stdin)
    password = inputs.get("password")
    if not password:
        print(json.dumps({"error": "Missing password"}), file=sys.stderr)
        sys.exit(1)

    # Generate a deterministic 16-byte salt by hashing the password itself
    # This acts as your static seed while keeping the salt unique to this password
    salt = hashlib.sha256(password.encode("utf-8")).digest()[:16]

    key = hashlib.pbkdf2_hmac("sha512", password.encode("utf-8"), salt, 100000)
    salt_b64 = base64.b64encode(salt).decode("utf-8")
    key_b64 = base64.b64encode(key).decode("utf-8")

    print(json.dumps({"pbkdf2_hash": f"@ByteArray({salt_b64}:{key_b64})"}))

except Exception as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(1)
EOT
  ]

  query = {
    password = var.webui_password
  }
}

resource "local_file" "qbit_default_config" {
  filename = abspath("${path.module}/configs/qbittorrent/qBittorrrent.conf")
  content = <<-EOT
    [AutoRun]
    enabled=false
    program=

    [BitTorrent]
    Session\AddTorrentStopped=false
    Session\DefaultSavePath=/downloads/
    Session\Port=6881
    Session\QueueingSystemEnabled=true
    Session\SSL\Port=26828
    Session\ShareLimitAction=Stop
    Session\TempPath=/downloads/incomplete/

    [LegalNotice]
    Accepted=true

    [Meta]
    MigrationVersion=8

    [Network]
    PortForwardingEnabled=false
    Proxy\HostnameLookupEnabled=false
    Proxy\Profiles\BitTorrent=true
    Proxy\Profiles\Misc=true
    Proxy\Profiles\RSS=true

    [Preferences]
    Connection\PortRangeMin=6881
    Connection\UPnP=false
    Downloads\SavePath=/downloads/
    Downloads\TempPath=/downloads/incomplete/
    # WebUI\APIKey=${local.api_key}
    WebUI\Address=*
    WebUI\Port=80
    WebUI\Password_PBKDF2="${data.external.pbkdf2_generator.result.pbkdf2_hash}"
    WebUI\ServerDomains=*
  EOT
}

resource "docker_container" "qbittorrent" {
  name     = "qbittorrent"
  hostname = "qbittorrent"
  image    = docker_image.qbittorrent.image_id

  restart = "unless-stopped"

  depends_on = [ local_file.torrents_dir ]

  lifecycle {
    replace_triggered_by = [ local_file.qbit_default_config ]
  }

  volumes {
    host_path      = local_file.qbit_default_config.filename
    container_path = "/config/qBittorrent/qBittorrent.conf"
  }

  volumes {
    host_path      = local.torrents_dir
    container_path = "/downloads"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels { 
    label = "traefik.http.routers.qbittorrent.service"
    value = "qbittorrent"
  }

  labels {
    label = "traefik.http.services.qbittorrent.loadbalancer.server.port"
    value = "80"
  }

  labels {
    label = "traefik.http.routers.qbittorrent.rule"
    value = "Host(`${local.qbittorrent_domain}`)"
  }

  labels {
    label = "traefik.http.routers.qbittorrent.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.qbittorrent.entrypoints"
    value = "websecure"
  }


  env = [
    "WEBUI_PORT=80"
  ]

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.qbittorrent_ip
  }
}
