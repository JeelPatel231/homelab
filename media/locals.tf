resource "random_string" "api_key" {
  length  = 32
  upper   = true
  lower   = true
  numeric = true
  special = false
}

locals {
  api_key = random_string.api_key.result
  flaresolverr_ip = cidrhost(var.module_subnet, 2)
  prowlarr_ip     = cidrhost(var.module_subnet, 3)
  radarr_anime_ip = cidrhost(var.module_subnet, 5)
  sonarr_anime_ip = cidrhost(var.module_subnet, 6)
}

locals {
  flaresolverr_domain = "flaresolverr.${var.docker_suffix}"
  prowlarr_domain     = "prowlarr.${var.docker_suffix}"

  # NOTE: lets encrypt says '_' is an invalid character when generating ssl. we use '-'
  radarr_anime_domain = "radarr-anime.${var.docker_suffix}"
  sonarr_anime_domain = "sonarr-anime.${var.docker_suffix}"
}

locals {
  tv_dir = "${var.media_dir}/tv"
  movies_dir = "${var.media_dir}/movies"
}

resource "local_file" "tv_dir" {
  filename = "${local.tv_dir}/.keep"
  content = ""
}

resource "local_file" "movies_dir" {
  filename = "${local.movies_dir}/.keep"
  content = ""
}