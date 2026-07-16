locals {
  api_key = var.api_key
  flaresolverr_ip = cidrhost(var.module_subnet, 2)
  prowlarr_ip     = cidrhost(var.module_subnet, 3)
  radarr_anime_ip = cidrhost(var.module_subnet, 5)
  sonarr_anime_ip = cidrhost(var.module_subnet, 6)
  qbittorrent_ip = cidrhost(var.module_subnet, 7)
  copyparty_ip = cidrhost(var.module_subnet, 8)
  jellyfin_ip = cidrhost(var.module_subnet, 9)
}

locals {
  flaresolverr_prefix = "flaresolverr"
  prowlarr_prefix = "prowlarr"
  radarr_anime_prefix = "radarr-anime"
  sonarr_anime_prefix = "sonarr-anime"
  qbittorrent_prefix = "qbittorrent"
  copyparty_prefix = "copyparty"
  jellyfin_prefix = "jellyfin"

  flaresolverr_domain = "${local.flaresolverr_prefix}.${var.docker_suffix}"
  prowlarr_domain     = "${local.prowlarr_prefix}.${var.docker_suffix}"
  qbittorrent_domain = "${local.qbittorrent_prefix}.${var.docker_suffix}"
  # NOTE: lets encrypt says '_' is an invalid character when generating ssl. we use '-'
  radarr_anime_domain = "${local.radarr_anime_prefix}.${var.docker_suffix}"
  sonarr_anime_domain = "${local.sonarr_anime_prefix}.${var.docker_suffix}"

  copyparty_domain = "${local.copyparty_prefix}.${var.docker_suffix}"
  jellyfin_domain = "${local.jellyfin_prefix}.${var.docker_suffix}"

}

resource "local_file" "media_folder" {
  filename = "${var.media_dir}/.keep"
  directory_permission = "0777"
  content = ""
}

locals {
  arr_permission = [
    "PGID=1000",
    "PUID=1000",
    "UMASK=002",
  ]
}
