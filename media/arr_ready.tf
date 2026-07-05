locals {
  health_timeout = "300"
}

resource "terraform_data" "wait_for_sonarr_anime" {
  depends_on = [docker_container.sonarr_anime]

  lifecycle {
    replace_triggered_by = [docker_container.sonarr_anime]
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOT
      timeout=${local.health_timeout}
      elapsed=0

      until curl -fs http://sonarr-anime.${var.internal_suffix}/api/v3/health -H 'X-Api-Key: ${local.api_key}' >/dev/null; do
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


resource "terraform_data" "wait_for_radarr_anime" {
  depends_on = [docker_container.radarr_anime]

  lifecycle {
    replace_triggered_by = [docker_container.radarr_anime]
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOT
      timeout=${local.health_timeout}
      elapsed=0

      until curl -fs http://radarr-anime.${var.internal_suffix}/api/v3/health -H 'X-Api-Key: ${local.api_key}' >/dev/null; do
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


resource "terraform_data" "wait_for_prowlarr" {
  depends_on = [docker_container.prowlarr]

  lifecycle {
    replace_triggered_by = [docker_container.prowlarr]
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOT
      timeout=${local.health_timeout}
      elapsed=0

      until curl -f -v http://prowlarr.${var.internal_suffix}/api/v1/health -H 'X-Api-Key: ${local.api_key}'; do
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
