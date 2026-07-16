terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
    random = {
      source = "hashicorp/random"
    }
    sonarr = {
      source = "devopsarr/sonarr"
    }
    radarr = {
      source = "devopsarr/radarr"
    }
    prowlarr = {
      source = "devopsarr/prowlarr"
    }
    terracurl = {
      source = "devops-rob/terracurl"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
