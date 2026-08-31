resource "sonarr_root_folder" "root_folder" {
  path = "/data/tv"

  depends_on = [terraform_data.wait_for_sonarr_anime]
  lifecycle {
    replace_triggered_by = [docker_container.sonarr_anime]
  }
}

resource "sonarr_indexer_torrent_rss" "subsplease" {
  enable_automatic_search = true
  name                    = "SubsPlease"
  base_url                = "https://subsplease.org/rss/?t&r=1080"
  allow_zero_size         = false
  minimum_seeders         = 1
  priority                = 1

  depends_on = [terraform_data.wait_for_sonarr_anime]
  lifecycle {
    replace_triggered_by = [docker_container.sonarr_anime]
  }
}

resource "sonarr_indexer_torrent_rss" "nyaa" {
  name                    = "Nyaa"
  base_url                = "https://nyaa.si/?page=rss"
  allow_zero_size         = false
  minimum_seeders         = 1
  priority                = 1

  depends_on = [terraform_data.wait_for_sonarr_anime]
  lifecycle {
    replace_triggered_by = [docker_container.sonarr_anime]
  }
}

resource "sonarr_download_client_qbittorrent" "qbit_client" {
  enable                     = true
  priority                   = 1
  name                       = "qBittorrent"
  host                       = "qbittorrent"
  port                       = 80
  username                   = "admin"
  password                   = var.webui_password
  tv_category                = "tv"
  use_ssl                    = false
  first_and_last             = true
  remove_completed_downloads = true

  depends_on = [terraform_data.wait_for_sonarr_anime]
  lifecycle {
    replace_triggered_by = [docker_container.sonarr_anime]
  }
}
