resource "prowlarr_tag" "flaresolverr" {
  label = "flaresolverr"

  depends_on = [
    terraform_data.wait_for_prowlarr,
    docker_container.flaresolverr,
    # TODO: add wait for flaresolverr here
  ]
  lifecycle {
    replace_triggered_by = [docker_container.prowlarr]
  }
}

resource "prowlarr_indexer_proxy_flaresolverr" "flaresolverr" {
  host = "http://flaresolverr"
  name = "Flaresolverr"
  tags = [ prowlarr_tag.flaresolverr.id ]
  request_timeout = 180

  depends_on = [
    terraform_data.wait_for_prowlarr,
  ]
  lifecycle {
    replace_triggered_by = [docker_container.prowlarr]
  }
}


resource "prowlarr_application_sonarr" "sonarr_anime" {
  name                  = "Sonarr [Anime]"
  sync_level            = "fullSync"
  base_url              = "http://sonarr-anime"
  prowlarr_url          = "http://prowlarr"
  api_key               = var.api_key
  sync_categories       = [5000, 5010, 5030, 5040, 5045, 5050, 5090]
  anime_sync_categories = [5070]

  depends_on = [
    terraform_data.wait_for_prowlarr,
    terraform_data.wait_for_sonarr_anime,
  ]
  lifecycle {
    replace_triggered_by = [docker_container.prowlarr]
  }
}

resource "prowlarr_application_radarr" "radarr_anime" {
  name            = "Radarr [Anime]"
  sync_level      = "fullSync"
  base_url        = "http://radarr-anime"
  prowlarr_url    = "http://prowlarr"
  api_key         = var.api_key
  sync_categories = [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060, 2070, 2080, 2090]

  depends_on = [
    terraform_data.wait_for_prowlarr,
    terraform_data.wait_for_sonarr_anime,
  ]
  lifecycle {
    replace_triggered_by = [docker_container.prowlarr]
  }
}

/// Indexers

# resource "prowlarr_tag" "cross_seed" {
#   label = "cross-seed"
# }

# {
#   "indexerUrls": [
#     "https://www.tokyotosho.info/",
#     "https://www.tokyotosho.se/",
#     "https://tokyo-tosho.net/"
#   ],
#   "legacyUrls": [
#     "https://tokyotosho.proxyportal.fun/",
#     "https://tokyotosho.uk-unblock.xyz/",
#     "https://tokyotosho.ind-unblock.xyz/",
#     "https://tokyotosho.unblocked.bar/",
#     "https://tokyotosho.proxyportal.pw/",
#     "https://tokyotosho.uk-unblock.pro/",
#     "https://tokyotosho.unblocked.rest/",
#     "https://tokyotosho.unblocked.monster/",
#     "https://tokyotosho.mrunblock.bond/",
#     "https://tokyotosho.nocensor.cloud/"
#   ],
#   "definitionName": "tokyotosho",
#   "description": "Tokyo Toshokan is a Public BitTorrent Library for JAPANESE Media",
#   "language": "en-US",
#   "enable": true,
#   "redirect": false,
#   "supportsRss": true,
#   "supportsSearch": true,
#   "supportsRedirect": false,
#   "supportsPagination": false,
#   "appProfileId": 1,
#   "protocol": "torrent",
#   "privacy": "public",
#   "capabilities": {
#     "limitsMax": 100,
#     "limitsDefault": 100,
#     "categories": [
#       {
#         "id": 5000,
#         "name": "TV",
#         "subCategories": [
#           {
#             "id": 5070,
#             "name": "TV/Anime",
#             "subCategories": []
#           }
#         ]
#       },
#       {
#         "id": 7000,
#         "name": "Books",
#         "subCategories": []
#       },
#       {
#         "id": 3000,
#         "name": "Audio",
#         "subCategories": []
#       },
#       {
#         "id": 6000,
#         "name": "XXX",
#         "subCategories": []
#       },
#       {
#         "id": 8000,
#         "name": "Other",
#         "subCategories": []
#       }
#     ],
#     "supportsRawSearch": false,
#     "searchParams": [
#       "q",
#       "q"
#     ],
#     "tvSearchParams": [
#       "q",
#       "season",
#       "ep"
#     ],
#     "movieSearchParams": [],
#     "musicSearchParams": [
#       "q"
#     ],
#     "bookSearchParams": [
#       "q"
#     ]
#   },
#   "priority": 25,
#   "downloadClientId": 0,
#   "added": "0001-01-01T00:00:00Z",
#   "sortName": "tokyo toshokan",
#   "fields": [
#     {
#       "name": "definitionFile",
#       "value": "tokyotosho"
#     },
#     {
#       "name": "baseUrl",
#       "value": "https://www.tokyotosho.info/"
#     },
#     {
#       "name": "baseSettings.queryLimit"
#     },
#     {
#       "name": "baseSettings.grabLimit"
#     },
#     {
#       "name": "baseSettings.limitsUnit",
#       "value": 0
#     },
#     {
#       "name": "torrentBaseSettings.appMinimumSeeders"
#     },
#     {
#       "name": "torrentBaseSettings.seedRatio"
#     },
#     {
#       "name": "torrentBaseSettings.seedTime"
#     },
#     {
#       "name": "torrentBaseSettings.packSeedTime"
#     },
#     {
#       "name": "torrentBaseSettings.preferMagnetUrl",
#       "value": false
#     },
#     {
#       "name": "cat",
#       "value": 0
#     }
#   ],
#   "infoLink": "https://wiki.servarr.com/prowlarr/supported-indexers#tokyotosho",
#   "tags": []
# }


resource "prowlarr_indexer" "tokyotosho" {
  enable          = true
  redirect        = false
  name            = "Tokyo Toshokan"
  implementation  = "Cardigann"
  config_contract = "CardigannSettings"
  protocol        = "torrent"
  app_profile_id  = 1
  priority        = 1
  depends_on = [ terraform_data.wait_for_prowlarr ]

  fields = [
    {
      "name" : "definitionFile",
      "text_value" : "tokyotosho"
    },
    {
      "name" : "baseUrl",
      "text_value" : "https://www.tokyotosho.info/"
    },
    {
      "name" : "baseSettings.limitsUnit",
      "number_value" : 0
    },
    {
      "name" : "torrentBaseSettings.preferMagnetUrl",
      "bool_value" : false
    },
    {
      "name" : "cat",
      "number_value" : 0
    }
  ]
}

resource "prowlarr_indexer" "subsplease" {
  enable          = true
  redirect        = false
  name            = "SubsPlease"
  implementation  = "SubsPlease"
  config_contract = "NoAuthTorrentBaseSettings"
  protocol        = "torrent"
  app_profile_id  = 1
  priority        = 1
  depends_on = [ terraform_data.wait_for_prowlarr ]

  fields = [
    {
      "name" : "baseSettings.limitsUnit",
      "number_value" : 0
    },
    {
      "name" : "baseUrl",
      "text_value" : "https://subsplease.org/"
    },
    {
      "name" : "torrentBaseSettings.preferMagnetUrl",
      "bool_value" : false
    }
  ]
}


resource "prowlarr_indexer" "bangumimoe" {
  enable          = true
  redirect        = false
  name            = "Bangumi Moe"
  implementation  = "Cardigann"
  config_contract = "CardigannSettings"
  protocol        = "torrent"
  app_profile_id  = 1
  priority        = 1
  depends_on = [ terraform_data.wait_for_prowlarr ]

  fields = [
    {
      "name" : "definitionFile",
      "text_value" : "bangumi-moe"
    },
    {
      "name" : "baseUrl",
      "text_value" : "https://bangumi.moe/",
    },
    {
      "name" : "baseSettings.limitsUnit",
      "number_value" : 0
    },
    {
      "name" : "torrentBaseSettings.preferMagnetUrl",
      "bool_value" : false
    },
  ]
}

# resource "prowlarr_indexer" "usenet_nzbplanet" {
#   enable          = true
#   redirect        = true
#   name            = "NzbPlanet"
#   implementation  = "Newznab"
#   config_contract = "NewznabSettings"
#   app_profile_id  = 1
#   protocol        = "usenet"
#   priority        = 1
#   tags            = [prowlarr_tag.cross_seed.id]

#   fields = [
#     {
#       name: "baseUrl"
#       text_value: "https://api.nzbplanet.net"
#     },
#     {
#       name: "apiPath"
#       text_value: "/api"
#     },
#     {
#       name: "apiKey"
#       sensitive_value: var.NZBPLANET_API_KEY
#     },
#     {
#       name: "vipExpiration"
#       text_value: ""
#     },
#     {
#       name: "baseSettings.queryLimit"
#       number_value: "20000"
#     },
#     {
#       name: "baseSettings.limitsUnit"
#       number_value: "0"
#     }
#   ]

#   lifecycle {
#     ignore_changes = [fields]
#   }
# }

# resource "prowlarr_indexer" "torrent_btetree" {
#   enable          = true
#   name            = "BT.etree"
#   implementation  = "Cardigann"
#   config_contract = "CardigannSettings"
#   app_profile_id  = 1
#   protocol        = "torrent"
#   priority        = 25
#   # tags            = [prowlarr_tag.cross_seed.id]

#   fields = [
#     {
#       name: "definitionFile"
#       text_value: "btetree"
#     },
#     {
#       name: "baseSettings.limitsUnit"
#       number_value: "0"
#     },
#     {
#       name: "sort"
#       number_value: "0"
#     }
#   ]

#   lifecycle {
#     ignore_changes = all
#   }
# }

# resource "prowlarr_indexer" "torrent_knaben" {
#   enable          = true
#   name            = "Knaben"
#   implementation  = "Knaben"
#   config_contract = "NoAuthTorrentBaseSettings"
#   app_profile_id  = 1
#   protocol        = "torrent"
#   priority        = 25
#   # tags            = [prowlarr_tag.cross_seed.id]

#   fields = [
#     {
#       name: "baseSettings.limitsUnit"
#       number_value: "0"
#     }
#   ]

#   lifecycle {
#     ignore_changes = all
#   }
# }

# resource "prowlarr_indexer" "torrent_limetorrents" {
#   enable          = true
#   name            = "LimeTorrents"
#   implementation  = "Cardigann"
#   config_contract = "CardigannSettings"
#   app_profile_id  = 1
#   protocol        = "torrent"
#   priority        = 25
#   # tags            = [prowlarr_tag.cross_seed.id]

#   fields = [
#     {
#       name: "definitionFile"
#       text_value: "limetorrents"
#     },
#     {
#       name: "baseSettings.limitsUnit"
#       number_value: "0"
#     },
#     {
#       name: "downloadlink"
#       number_value: "1"
#     },
#     {
#       name: "downloadlink2"
#       number_value: "0"
#     },
#     {
#       name: "sort"
#       number_value: "0"
#     }
#   ]

#   lifecycle {
#     ignore_changes = all
#   }
# }

# resource "prowlarr_indexer" "torrent_showrss" {
#   enable          = true
#   name            = "showRSS"
#   implementation  = "Cardigann"
#   config_contract = "CardigannSettings"
#   app_profile_id  = 1
#   protocol        = "torrent"
#   priority        = 25
#   # tags            = [prowlarr_tag.cross_seed.id]

#   fields = [
#     {
#       name: "definitionFile"
#       text_value: "showrss"
#     },
#     {
#       name: "baseSettings.limitsUnit"
#       number_value: "0"
#     }
#   ]

#   lifecycle {
#     ignore_changes = all
#   }
# }

# resource "prowlarr_indexer" "torrent_thepiratebay" {
#   enable          = true
#   name            = "The Pirate Bay"
#   implementation  = "Cardigann"
#   config_contract = "CardigannSettings"
#   app_profile_id  = 1
#   protocol        = "torrent"
#   priority        = 25
#   # tags            = [prowlarr_tag.cross_seed.id]

#   fields = [
#     {
#       name: "definitionFile"
#       text_value: "thepiratebay"
#     },
#     {
#       name: "baseSettings.limitsUnit"
#       number_value: "0"
#     }
#   ]

#   lifecycle {
#     ignore_changes = all
#   }
# }

# resource "prowlarr_indexer" "torrent_torrentdownload" {
#   enable          = true
#   name            = "TorrentDownload"
#   implementation  = "Cardigann"
#   config_contract = "CardigannSettings"
#   app_profile_id  = 1
#   protocol        = "torrent"
#   priority        = 25
#   # tags            = [prowlarr_tag.cross_seed.id]

#   fields = [
#     {
#       name: "definitionFile"
#       text_value: "torrentdownload"
#     },
#     {
#       name: "baseSettings.limitsUnit"
#       number_value: "0"
#     },
#     {
#       name: "sort"
#       number_value: "1"
#     }
#   ]

#   lifecycle {
#     ignore_changes = all
#   }
# }

# resource "prowlarr_indexer" "torrent_uindex" {
#   enable          = true
#   name            = "Uindex"
#   implementation  = "Cardigann"
#   config_contract = "CardigannSettings"
#   app_profile_id  = 1
#   protocol        = "torrent"
#   priority        = 25
#   # tags            = [prowlarr_tag.cross_seed.id]

#   fields = [
#     {
#       name: "definitionFile"
#       text_value: "uindex"
#     },
#     {
#       name: "baseSettings.limitsUnit"
#       number_value: "0"
#     }
#   ]

#   lifecycle {
#     ignore_changes = all
#   }
# }
