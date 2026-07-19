locals {
  jellyfin_dockerfile = abspath("${path.module}/dockerfiles/Dockerfile.jellyfin")
}

resource "terraform_data" "jellyfin_dockerfile_hash" {
  input = filesha1(local.jellyfin_dockerfile)
}

resource "docker_image" "jellyfin" {
  name = "jellyfin-custom-python"
  
  lifecycle {
    replace_triggered_by = [ terraform_data.jellyfin_dockerfile_hash ]
  }

  build {
    context = "."
    dockerfile = local.jellyfin_dockerfile
  }
}

locals {
  jellyfin_init_scripts_dir = abspath("${path.module}/generated/init/jellyfin/")
  jellyfin_init_support_dir = abspath("${path.module}/generated/init-support/jellyfin/")

  jellyfin_server_name             = "Jellyfin"
  jellyfin_ui_culture              = "en-US"
  jellyfin_metadata_country_code   = "US"
  jellyfin_preferred_metadata_lang = "en"
}

resource "local_file" "jellyfin_setup_script" {
  filename = abspath("${local.jellyfin_init_scripts_dir}/01-setup-jellyfin")
  content  = <<-EOT
    #!/bin/bash
    (
      python3 /jellyfin-init-support/setup.py
    ) &
    disown
  EOT
}

resource "local_file" "jellyfin_setup_py" {
  filename = abspath("${local.jellyfin_init_support_dir}/setup.py")
  content  = <<-EOT
    import json
    import os
    import sys
    import time
    import urllib.error
    import urllib.parse
    import urllib.request

    BASE_URL = "http://localhost:8096"
    AUTH_HEADER = 'MediaBrowser Client="Terraform-Init", Device="Terraform-Init", DeviceId="jellyfin-init-script", Version="1.0.0"'
    LOG_PATH = "/tmp/jellyfin-init.log"

    TYPE_OPTIONS = {
        "movies": [
            {
                "Type": "Movie",
                "MetadataFetchers": ["TheMovieDb"],
                "MetadataFetcherOrder": ["TheMovieDb"],
                "ImageFetchers": ["TheMovieDb"],
                "ImageFetcherOrder": ["TheMovieDb"],
            },
        ],
        "tvshows": [
            {
                "Type": type_name,
                "MetadataFetchers": ["TheMovieDb"],
                "MetadataFetcherOrder": ["TheMovieDb"],
                "ImageFetchers": ["TheMovieDb"],
                "ImageFetcherOrder": ["TheMovieDb"],
            }
            for type_name in ("Series", "Season", "Episode")
        ],
    }


    def log(message):
        print('[jellyfin-init]', message)
        # with open(LOG_PATH, "a") as f:
        #     f.write(f"[jellyfin-init] {message}\n")


    def request(method, path, headers=None, body=None):
        url = BASE_URL + path
        hdrs = {"Authorization": AUTH_HEADER}
        if headers:
            hdrs.update(headers)

        data = None
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            hdrs["Content-Type"] = "application/json"

        req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
        while True:
            try:
                with urllib.request.urlopen(req, timeout=15) as resp:
                    status = resp.status                    
                    raw = resp.read()
                    break
                
            except urllib.error.HTTPError as e:
                status = e.code
                if status == 503:
                    print("Service Unavailable, Retrying!")
                    time.sleep(2)
                    continue

                raw = e.read()
                break

            except urllib.error.URLError as e:
                if isinstance(e.reason, ConnectionRefusedError) or getattr(e.reason, "errno", None) == 111:
                    log("Connection refused, retrying...")
                    time.sleep(2)
                    continue
                
                return None, str(e)

        text = raw.decode("utf-8", errors="replace")
        try:
            parsed = json.loads(text) if text else None
        except ValueError:
            parsed = None
        return status, parsed if parsed is not None else text


    def log_step(label, status, body):
        log(f"{label} -> HTTP {status}")
        if status is None or status >= 400:
            log(f"{label} response: {body}")


    def wait_for_api():
        log("waiting for API...")
        while True:
            status, body = request("GET", "/System/Info/Public")
            if status == 200 and isinstance(body, dict):
                log("API is up")
                return body
            time.sleep(2)


    def ensure_library(existing_names, authed_headers, name, collection_type, path):
        if name in existing_names:
            log(f"library '{name}' already exists, skipping")
            return

        log(f"creating library '{name}'")
        options = {
            "LibraryOptions": {
                "Enabled": True,
                "EnableRealtimeMonitor": True,
                "EnableInternetProviders": True,
                "PathInfos": [{"Path": path}],
                "PreferredMetadataLanguage": "${local.jellyfin_preferred_metadata_lang}",
                "MetadataCountryCode": "${local.jellyfin_metadata_country_code}",
                "TypeOptions": TYPE_OPTIONS[collection_type],
            }
        }
        qs = urllib.parse.urlencode(
            {"name": name, "collectionType": collection_type, "refreshLibrary": "false"}
        )
        status, body = request(
            "POST", f"/Library/VirtualFolders?{qs}", headers=authed_headers, body=options
        )
        log_step(f"Library/VirtualFolders ({name})", status, body)


    def main():
        admin_username = os.environ["JELLYFIN_ADMIN_USERNAME"]
        admin_password = os.environ["JELLYFIN_ADMIN_PASSWORD"]

        public_info = wait_for_api()

        if not public_info.get("StartupWizardCompleted", False):
            log("wizard not completed, running it")

            status, body = request(
                "POST",
                "/Startup/Configuration",
                body={
                    "UICulture": "${local.jellyfin_ui_culture}",
                    "MetadataCountryCode": "${local.jellyfin_metadata_country_code}",
                    "PreferredMetadataLanguage": "${local.jellyfin_preferred_metadata_lang}",
                    "ServerName": "${local.jellyfin_server_name}",
                },
            )
            log_step("Startup/Configuration", status, body)

            status, body = request("GET", "/Startup/User")
            log_step("Startup/User (GET)", status, body)

            status, body = request(
                "POST",
                "/Startup/User",
                body={"Name": admin_username, "Password": admin_password},
            )
            log_step("Startup/User (POST)", status, body)

            if status is None or status >= 400:
                log("ERROR: setting admin user failed, NOT completing wizard (will retry on next restart)")
                sys.exit(1)

            status, body = request("POST", "/Startup/Complete", body={})
            log_step("Startup/Complete", status, body)
            log("wizard completed")
        else:
            log("wizard already completed, skipping")

        status, body = request(
            "POST",
            "/Users/AuthenticateByName",
            body={"Username": admin_username, "Pw": admin_password},
        )
        log_step("AuthenticateByName", status, body)

        token = body.get("AccessToken") if isinstance(body, dict) else None
        if not token:
            log("ERROR: failed to authenticate, aborting library setup")
            sys.exit(1)

        authed_headers = {"Authorization": f'{AUTH_HEADER}, Token="{token}"'}

        status, existing = request("GET", "/Library/VirtualFolders", headers=authed_headers)
        existing_names = {lib.get("Name") for lib in existing} if isinstance(existing, list) else set()

        ensure_library(existing_names, authed_headers, "Movies", "movies", "/data/movies")
        ensure_library(existing_names, authed_headers, "TV Shows", "tvshows", "/data/tv")

        status, body = request("POST", "/Library/Refresh", headers=authed_headers, body={})
        log_step("Library/Refresh", status, body)

        log("done")


    if __name__ == "__main__":
        main()
  EOT
}

resource "docker_container" "jellyfin" {
  name     = "jellyfin"
  hostname = "jellyfin"
  image    = docker_image.jellyfin.image_id

  restart = "unless-stopped"

  depends_on = [local_file.media_folder, local_file.jellyfin_setup_script, local_file.jellyfin_setup_py]

  lifecycle {
    replace_triggered_by = [local_file.jellyfin_setup_script, local_file.jellyfin_setup_py]
  }

  volumes {
    host_path      = local.jellyfin_init_scripts_dir
    container_path = "/custom-cont-init.d/"
  }

  volumes {
    host_path      = local.jellyfin_init_support_dir
    container_path = "/jellyfin-init-support/"
    read_only      = true
  }

  volumes {
    host_path      = var.media_dir
    container_path = "/data"
    read_only      = true
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  # labels {
  #   label = "traefik.http.routers.jellyfin.service"
  #   value = "jellyfin"
  # }

  # labels {
  #   label = "traefik.http.services.jellyfin.loadbalancer.server.port"
  #   value = "8096"
  # }

  labels {
    label = "traefik.http.routers.jellyfin.rule"
    value = "Host(`${local.jellyfin_domain}`)"
  }

  labels {
    label = "traefik.http.routers.jellyfin.tls.certResolver"
    value = "porkbun"
  }

  labels {
    label = "traefik.http.routers.jellyfin.entrypoints"
    value = "websecure"
  }

  env = concat([
    "JELLYFIN_ADMIN_USERNAME=${var.jellyfin_admin_username}",
    "JELLYFIN_ADMIN_PASSWORD=${var.jellyfin_admin_password}",
    "JELLYFIN_FFMPEG=/bin/false",
  ], local.arr_permission)

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.jellyfin_ip
  }
}
