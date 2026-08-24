data "docker_registry_image" "qbittorrent" {
  name = "lscr.io/linuxserver/qbittorrent:latest"
}

resource "docker_image" "qbittorrent" {
  name          = data.docker_registry_image.qbittorrent.name
  pull_triggers = [data.docker_registry_image.qbittorrent.sha256_digest]
}

locals {
  torrents_dir     = abspath("${var.media_dir}/torrents")
  qbit_init_scripts_dir = abspath("${path.module}/generated/init/qbit")
}

resource "local_file" "password_config" {
  filename = abspath("${local.qbit_init_scripts_dir}/01-set-password")
  content  = <<-EOT
  #!/bin/bash

  python <<PYTHON_INIT
  print("[qbittorrent-webui-password] Setting qBittorrent WebUI password from QBITTORRENT_WEBUI_PASSWORD environment variable.")

  import base64
  import hashlib
  import os
  import pathlib
  import sys

  config_path = pathlib.Path("/config/qBittorrent/qBittorrent.conf")
  password = os.environ.get("QBITTORRENT_WEBUI_PASSWORD")

  if password is None:
      print("[qbittorrent-webui-password] QBITTORRENT_WEBUI_PASSWORD is not set; keeping qBittorrent's generated password behavior.")
      sys.exit(0)

  salt = os.urandom(16)
  password_hash = hashlib.pbkdf2_hmac("sha512", password.encode("utf-8"), salt, 100000)
  config_value = '@ByteArray({}:{})'.format(
      base64.b64encode(salt).decode("ascii"),
      base64.b64encode(password_hash).decode("ascii"),
  )

  if config_path.exists():
      lines = config_path.read_text(encoding="utf-8").splitlines()
  else:
      lines = ["[LegalNotice]", "Accepted=true", "", "[Preferences]"]

  lines = [
      line for line in lines
      if not line.startswith("WebUI\\\Password_PBKDF2=")
      and not line.startswith("WebUI\\\Password_ha1=")
  ]

  if "[Preferences]" not in lines:
      if lines and lines[-1] != "":
          lines.append("")
      lines.append("[Preferences]")

  pref_index = lines.index("[Preferences]")
  insert_at = pref_index + 1

  while insert_at < len(lines):
      line = lines[insert_at]
      if line.startswith("[") and line.endswith("]"):
          break
      insert_at += 1

  lines.insert(insert_at, f'WebUI\\\Password_PBKDF2="{config_value}"')

  config_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

  print("[qbittorrent-webui-password] Applied password from QBITTORRENT_WEBUI_PASSWORD.")
  PYTHON_INIT

  EOT
}

resource "local_file" "qbit_default_config" {
  filename = abspath("${path.module}/generated/configs/qbittorrent/qBittorrent.conf")
  content  = <<-EOT
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
    Downloads\SavePath=/data/torrents/
    Downloads\TempPath=/data/torrents/incomplete/
    WebUI\LocalHostAuth=false
    WebUI\APIKey=${local.qbit_api_key}
    WebUI\Address=*
    WebUI\Port=80
    WebUI\ServerDomains=*
  EOT
}

resource "local_file" "default_config_init" {
  filename = abspath("${local.qbit_init_scripts_dir}/01-copy-init-config")
  content  = <<-EOT
    #!/bin/bash

    cp /defaults/qBittorrent.conf /config/qBittorrent/qBittorrent.conf

    echo "Copy of default file complete!"
  EOT
}

resource "local_file" "init_preferences" {
  filename = abspath("${local.qbit_init_scripts_dir}/02-set-preferences")
  content  = <<-EOT
    #!/bin/bash

    set_preferences() {
      json_data=$(cat <<'DATA'
    {
      "locale":"en",
      "confirm_torrent_deletion":true,
      "torrent_content_layout":"Subfolder",
      "merge_trackers":true,
      "auto_delete_mode":1,
      "preallocate_all":false,
      "auto_tmm_enabled":true,
      "torrent_changed_tmm_enabled":true,
      "save_path_changed_tmm_enabled":true,
      "category_changed_tmm_enabled":true,
      "use_category_paths_in_manual_mode":true,
      "save_path":"/data/torrents",
      "temp_path_enabled":false,
      "temp_path":"/data/torrents/incomplete",
      "listen_port":6881,
      "upnp":false,
      "max_connec":500,
      "max_connec_per_torrent":100,
      "max_uploads":20,
      "max_uploads_per_torrent":4,
      "max_active_checking_torrents":1,
      "queueing_enabled":true,
      "max_active_downloads":3,
      "max_active_uploads":3,
      "max_active_torrents":5,
      "bypass_local_auth":true
    }
    DATA
      )

      curl -v -X POST \
        http://localhost:80/api/v2/app/setPreferences \
        --data-urlencode "json=$json_data"
    }

    (
      until curl -fsS http://localhost:80/api/v2/app/version >/dev/null 2>&1; do
        echo "Waiting for qBittorrent WebUI to be available..."
        sleep 1
      done

      set_preferences
      echo "qBittorrent preferences have been set."
    ) &
  EOT
}

resource "docker_container" "qbittorrent" {
  name     = "qbittorrent"
  hostname = "qbittorrent"
  image    = docker_image.qbittorrent.image_id

  restart = "unless-stopped"

  depends_on = [
    local_file.media_folder,
    local_file.qbit_default_config,
    local_file.password_config,
    local_file.init_preferences
  ]

  lifecycle {
    replace_triggered_by = [
      local_file.qbit_default_config,
      local_file.password_config,
      local_file.init_preferences
    ]
  }

  volumes {
    host_path      = local_file.qbit_default_config.filename
    container_path = "/defaults/qBittorrent.conf"
    read_only      = true
  }

  volumes {
    host_path      = local.qbit_init_scripts_dir
    container_path = "/custom-cont-init.d/"
    # read_only = true
  }

  volumes {
    host_path      = local.torrents_dir
    container_path = "/data/torrents"
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


  env = concat([
    "WEBUI_PORT=80",
    "QBITTORRENT_WEBUI_PASSWORD=${var.webui_password}",
  ], local.arr_permission)

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.qbittorrent_ip
  }
}
