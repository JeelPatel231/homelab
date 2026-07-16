locals {
  router_ip   = cidrhost(var.module_subnet, 0)
}

resource "local_file" "ts_init_script" {
  filename = abspath("${path.module}/generated/init.sh")
  content = <<-EOT
  #!/bin/sh

  # Apply iptables rules at runtime
  iptables -A FORWARD -i tailscale0 -o eth0 -j ACCEPT
  iptables -A FORWARD -i eth0 -o tailscale0 -m state --state RELATED,ESTABLISHED -j ACCEPT

  /usr/local/bin/containerboot
  EOT
}

resource "tailscale_acl" "policy" {
  acl = jsonencode({
    tagOwners = {
      "tag:router"    = ["autogroup:admin"]
    }
    autoApprovers = {
      routes = {
        "${var.advertise_range}": ["tag:router"],
      }
    }

    grants = [
      {
        "src": ["autogroup:admin"],
        "dst": ["*"],
        "ip":  ["*"],
      },
      {
        "src": ["autogroup:member"],
        "dst": ["tag:router"],
        "ip":  ["*"],
      }
    ],
    nodeAttrs: [
      {
        // Funnel policy, which lets tailnet members control Funnel
        // for their own devices.
        // Learn more at https://tailscale.com/kb/1223/tailscale-funnel/
        target: ["autogroup:member"],
        attr:   ["funnel"],
      },
    ],
  })

  reset_acl_on_destroy = true
  overwrite_existing_content = var.overwrite_tailnet_acl
}


resource "tailscale_tailnet_key" "docker_key" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "Docker Routing Container Key"
  tags = ["tag:router"]
  depends_on = [ tailscale_acl.policy ]
}

resource "docker_volume" "tailscale_auth_state" {
  name = "tailscale_auth_state"
}

resource "docker_container" "tailscale_packet_router" {
  name     = "tailscale-router"
  image    = "tailscale/tailscale:latest"
  hostname = "tailscale-router"

  env = [
    # IPRange is always a subset of subnet, and we only expose the cidr range which is usable.
    "TS_EXTRA_ARGS=--advertise-routes=${var.advertise_range}",
    "TS_STATE_DIR=/var/lib/tailscale",
    "TS_USERSPACE=false",
    "TS_AUTHKEY=${tailscale_tailnet_key.docker_key.key}"
  ]

  command = ["sh", "/init.sh"]

  restart = "always"

  capabilities {
    add = ["CAP_NET_ADMIN"]
  }

  devices {
    host_path      = "/dev/net/tun"
    container_path = "/dev/net/tun"
    permissions    = "rwm"
  }

  volumes {
    host_path = local_file.ts_init_script.filename
    container_path = "/init.sh"
  }

  # we persist state so when container can reauth as the same instance
  # we dont use a host mount in workdir as the state is internal and we never need to touch it or migrate it
  volumes {
    volume_name    = docker_volume.tailscale_auth_state.name
    container_path = "/var/lib/tailscale"
  }

  sysctls = {
    "net.ipv4.ip_forward" = "1"
  }

  networks_advanced {
    name = var.network_name
    ipv4_address = local.router_ip
  }
}
