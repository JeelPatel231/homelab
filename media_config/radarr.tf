resource "radarr_root_folder" "root_folder" {
  path = "/data/movies"
}

resource "radarr_download_client_qbittorrent" "qbit_client" {
  enable                     = true
  priority                   = 1
  name                       = "qBittorrent"
  host                       = "qbittorrent"
  port                       = 80
  username                   = "admin"
  password                   = var.qbit_webui_password
  movie_category             = "movies"
  use_ssl                    = false
  first_and_last             = true
  remove_completed_downloads = true
}

