data "docker_registry_image" "jellyfin" {
  name = "lscr.io/linuxserver/jellyfin:latest"
}

resource "docker_image" "jellyfin" {
  name          = data.docker_registry_image.jellyfin.name
  pull_triggers = [data.docker_registry_image.jellyfin.sha256_digest]
}

locals {
  jellyfin_config_dir = abspath("${var.media_dir}/jellyfin_config")
}

resource "docker_container" "jellyfin" {
  name     = "jellyfin"
  hostname = "jellyfin"
  image    = docker_image.jellyfin.image_id

  restart = "unless-stopped"

  depends_on = [local_file.media_folder]

  volumes {
    host_path      = local.jellyfin_config_dir
    container_path = "/config"
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

  env = local.arr_permission

  networks_advanced {
    name         = var.network_name
    ipv4_address = local.jellyfin_ip
  }
}

locals {
  jellyfin_url = "http://jellyfin:8096"

  jellyfin_server_name             = "Jellyfin"
  jellyfin_ui_culture              = "en-US"
  jellyfin_metadata_country_code   = "US"
  jellyfin_preferred_metadata_lang = "en"

  # IMPORTANT: keep this DeviceId static so re-applies authenticate the same "device"
  jellyfin_base_auth_header = "MediaBrowser Client=\"Terraform\", Device=\"Terraform\", DeviceId=\"terraform-jellyfin-setup\", Version=\"1.0.0\""

  jellyfin_access_token         = jsondecode(terracurl_request.jellyfin_auth.response).AccessToken
  jellyfin_authenticated_header = "${local.jellyfin_base_auth_header}, Token=\"${local.jellyfin_access_token}\""

  jellyfin_movie_type_options = [{
    Type                 = "Movie"
    MetadataFetchers     = ["TheMovieDb"]
    MetadataFetcherOrder = ["TheMovieDb"]
    ImageFetchers        = ["TheMovieDb"]
    ImageFetcherOrder    = ["TheMovieDb"]
  }]

  jellyfin_tvshow_type_options = [
    {
      Type                 = "Series"
      MetadataFetchers     = ["TheMovieDb"]
      MetadataFetcherOrder = ["TheMovieDb"]
      ImageFetchers        = ["TheMovieDb"]
      ImageFetcherOrder    = ["TheMovieDb"]
    },
    {
      Type                 = "Season"
      MetadataFetchers     = ["TheMovieDb"]
      MetadataFetcherOrder = ["TheMovieDb"]
      ImageFetchers        = ["TheMovieDb"]
      ImageFetcherOrder    = ["TheMovieDb"]
    },
    {
      Type                 = "Episode"
      MetadataFetchers     = ["TheMovieDb"]
      MetadataFetcherOrder = ["TheMovieDb"]
      ImageFetchers        = ["TheMovieDb"]
      ImageFetcherOrder    = ["TheMovieDb"]
    }
  ]

  jellyfin_libraries = {
    movies = {
      display_name    = "Movies"
      collection_type = "movies"
      path            = "/data/movies"
      type_options    = local.jellyfin_movie_type_options
    }
    tv = {
      display_name    = "TV Shows"
      collection_type = "tvshows"
      path            = "/data/tv"
      type_options    = local.jellyfin_tvshow_type_options
    }
  }
}

resource "terraform_data" "wait_for_jellyfin" {
  depends_on = [docker_container.jellyfin]

  lifecycle {
    replace_triggered_by = [docker_container.jellyfin]
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]

    command = <<-EOT
      timeout=${local.health_timeout}
      elapsed=0

      until curl -fs ${local.jellyfin_url}/health >/dev/null; do
        if [ $elapsed -ge $timeout ]; then
          echo "Timed out waiting for health endpoint."
          exit 1
        fi

        sleep 5
        elapsed=$((elapsed + 5))
      done

      echo "Container is healthy."
    EOT
  }
}

# Step 1: Set initial server configuration
resource "terracurl_request" "jellyfin_startup_configuration" {
  depends_on = [terraform_data.wait_for_jellyfin]

  name   = "jellyfin_startup_configuration"
  url    = "${local.jellyfin_url}/Startup/Configuration"
  method = "POST"

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = local.jellyfin_base_auth_header
  }

  request_body = jsonencode({
    UICulture                 = local.jellyfin_ui_culture
    MetadataCountryCode       = local.jellyfin_metadata_country_code
    PreferredMetadataLanguage = local.jellyfin_preferred_metadata_lang
    ServerName                = local.jellyfin_server_name
  })

  response_codes = [204]
}

# Step 2: GET the startup user (note: this creates the initial user internally!)
resource "terracurl_request" "jellyfin_get_startup_user" {
  depends_on = [terracurl_request.jellyfin_startup_configuration]

  name   = "jellyfin_get_startup_user"
  url    = "${local.jellyfin_url}/Startup/User"
  method = "GET"

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = local.jellyfin_base_auth_header
  }

  response_codes = [200]
}

# Step 3: Set the admin username and password
resource "terracurl_request" "jellyfin_startup_user" {
  depends_on = [terracurl_request.jellyfin_get_startup_user]

  name   = "jellyfin_startup_user"
  url    = "${local.jellyfin_url}/Startup/User"
  method = "POST"

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = local.jellyfin_base_auth_header
  }

  request_body = jsonencode({
    Name     = var.jellyfin_admin_username
    Password = var.jellyfin_admin_password
  })

  response_codes = [204]
}

# Step 4: Complete the startup wizard
resource "terracurl_request" "jellyfin_complete_wizard" {
  depends_on = [terracurl_request.jellyfin_startup_user]

  name   = "jellyfin_complete_wizard"
  url    = "${local.jellyfin_url}/Startup/Complete"
  method = "POST"

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = local.jellyfin_base_auth_header
  }

  request_body = "{}"

  response_codes = [204]
}

# Authenticate to get an access token for the post-wizard calls below
resource "terracurl_request" "jellyfin_auth" {
  depends_on = [terracurl_request.jellyfin_complete_wizard]

  name   = "jellyfin_auth"
  url    = "${local.jellyfin_url}/Users/AuthenticateByName"
  method = "POST"

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = local.jellyfin_base_auth_header
  }

  request_body = jsonencode({
    Username = var.jellyfin_admin_username
    Pw       = var.jellyfin_admin_password
  })

  response_codes = [200]
}

# Create the Movies/TV libraries pointed at the folders radarr_anime/sonarr_anime manage
resource "terracurl_request" "jellyfin_libraries" {
  depends_on = [terracurl_request.jellyfin_auth]
  for_each   = local.jellyfin_libraries

  name   = "jellyfin_library_${each.key}"
  method = "POST"
  url    = "${local.jellyfin_url}/Library/VirtualFolders?name=${urlencode(each.value.display_name)}&collectionType=${each.value.collection_type}&refreshLibrary=false"

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = local.jellyfin_authenticated_header
  }

  request_body = jsonencode({
    LibraryOptions = {
      Enabled                   = true
      EnableRealtimeMonitor     = true
      EnableInternetProviders   = true
      PathInfos                 = [{ Path = each.value.path }]
      PreferredMetadataLanguage = local.jellyfin_preferred_metadata_lang
      MetadataCountryCode       = local.jellyfin_metadata_country_code
      TypeOptions               = each.value.type_options
    }
  })

  response_codes = [204]

  destroy_method = "DELETE"
  destroy_url    = "${local.jellyfin_url}/Library/VirtualFolders?name=${urlencode(each.value.display_name)}&refreshLibrary=false"
  destroy_headers = {
    "Content-Type"  = "application/json"
    "Authorization" = local.jellyfin_authenticated_header
  }
  destroy_response_codes = [204]
}

# Kick off an initial scan so the libraries aren't empty until the next scheduled scan
resource "terracurl_request" "jellyfin_scan_libraries" {
  depends_on = [terracurl_request.jellyfin_libraries]

  name   = "jellyfin_scan_libraries"
  url    = "${local.jellyfin_url}/Library/Refresh"
  method = "POST"

  headers = {
    "Content-Type"  = "application/json"
    "Authorization" = local.jellyfin_authenticated_header
  }

  request_body   = "{}"
  response_codes = [204]
}
