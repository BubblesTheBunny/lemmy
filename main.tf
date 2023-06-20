terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~>2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}

provider "tls" {}

provider "digitalocean" {
  token = var.do_token
}

provider "cloudflare" {}

locals {
  cidr  = "10.1.0.0/16"
  my-ip = trimspace(data.http.my-ip.response_body)
}

data "http" "my-ip" {
  url = "https://icanhazip.com"
}

data "digitalocean_sizes" "default" {
  filter {
    key    = "regions"
    values = ["nyc3"]
  }
  sort {
    key       = "price_monthly"
    direction = "asc"
  }
}

data "digitalocean_volume" "postgres" {
  name   = "postgres"
  region = "nyc3"
}

data "digitalocean_volume" "pictrs" {
  name   = "pictrs"
  region = "nyc3"
}

data "digitalocean_volume" "lemmy_ui" {
  name   = "lemmyui"
  region = "nyc3"
}

resource "digitalocean_ssh_key" "bastion-ssh" {
  name       = "bastion-ssh"
  public_key = file("bastion-ssh.pub")
}

resource "digitalocean_ssh_key" "server-ssh" {
  name       = "server-ssh"
  public_key = file("server-ssh.pub")
}

resource "digitalocean_vpc" "lemmy_vpc" {
  name     = "lemmyvpc"
  region   = "nyc3"
  ip_range = local.cidr
}

resource "digitalocean_droplet" "bastion" {
  image    = "rockylinux-9-x64"
  name     = "bastion"
  size     = data.digitalocean_sizes.default.sizes[0].slug
  vpc_uuid = digitalocean_vpc.lemmy_vpc.id
  ssh_keys = [digitalocean_ssh_key.bastion-ssh.fingerprint]
  region   = "nyc3"
}

resource "digitalocean_droplet" "lemmy" {
  image    = "rockylinux-9-x64"
  name     = "lemmyserver"
  size     = data.digitalocean_sizes.default.sizes[1].slug
  vpc_uuid = digitalocean_vpc.lemmy_vpc.id
  ssh_keys = [digitalocean_ssh_key.server-ssh.fingerprint]
  region   = "nyc3"
}

resource "digitalocean_project" "bubbles" {
  name        = "bubbles"
  description = "Project for bubblesthebunny lemmy instance"
  purpose     = "Holding resources"
  environment = var.environment
  resources = [
    digitalocean_droplet.lemmy.urn,
    digitalocean_droplet.bastion.urn,
  ]
}

resource "digitalocean_volume_attachment" "postgres" {
  droplet_id = digitalocean_droplet.lemmy.id
  volume_id  = data.digitalocean_volume.postgres.id
}

resource "digitalocean_volume_attachment" "pictrs" {
  droplet_id = digitalocean_droplet.lemmy.id
  volume_id  = data.digitalocean_volume.pictrs.id
}

resource "digitalocean_volume_attachment" "lemmy_ui" {
  droplet_id = digitalocean_droplet.lemmy.id
  volume_id  = data.digitalocean_volume.lemmy_ui.id
}

resource "digitalocean_firewall" "bastion-firewall" {
  name        = "bastion-firewall"
  droplet_ids = [digitalocean_droplet.bastion.id]
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [local.my-ip]
  }
  outbound_rule {
    protocol                = "tcp"
    port_range              = "22"
    destination_droplet_ids = [digitalocean_droplet.lemmy.id]
  }
}

resource "digitalocean_firewall" "lemmy-ssh" {
  name        = "lemmy-ssh"
  droplet_ids = [digitalocean_droplet.lemmy.id]
  inbound_rule {
    protocol           = "tcp"
    port_range         = "22"
    source_droplet_ids = [digitalocean_droplet.bastion.id]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "80"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "443"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "7844"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "cloudflare_tunnel" "lemmy" {
  account_id = var.cloudflare_account_id
  name       = "lemmy-tunnel"
  secret     = var.tunnel_secret
}

resource "cloudflare_tunnel_route" "lemmy" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.lemmy.id
  network    = "${digitalocean_droplet.lemmy.ipv4_address}/32"
}

resource "cloudflare_record" "lemmy" {
  name    = var.domain
  type    = "CNAME"
  zone_id = var.cloudflare_zone_id
  value   = "${cloudflare_tunnel.lemmy.id}.cfargotunnel.com"
  proxied = true
}

resource "local_file" "tunnel_creds" {
  filename = "${path.module}/ansible/roles/cloudflared/templates/${cloudflare_tunnel.lemmy.id}.json"
  content  = <<-EOT
  {
    "AccountTag": "${var.cloudflare_account_id}",
    "TunnelID": "${cloudflare_tunnel.lemmy.id}",
    "TunnelName": "${cloudflare_tunnel.lemmy.name}",
    "TunnelSecret": "{{ tunnel_secret }}"
  }
EOT
}

resource "local_file" "hosts_yaml" {
  filename = "${path.module}/ansible/hosts.yaml"
  content  = <<-EOT
  ---
  all:
    hosts:
      bastion:
      lemmyserver:
        domain: ${var.domain}
        tunnel_id: ${cloudflare_tunnel.lemmy.id}
        tunnel_secret: ${var.tunnel_secret}
        lemmy_base_dir: /srv/lemmy
        lemmy_port: 8536
        lemmy_ui_port: 1235
        pictrs_port: 1236
        lemmy_version: ${var.lemmy_version}
        lemmy_docker_image: dessalines/lemmy:${var.lemmy_version}
        lemmy_docker_ui_image: dessalines/lemmy-ui:${var.lemmy_version}
        postgres_password: ${var.postgres_password}
    vars:
      ansible_ssh_common_args: -F ssh_config
EOT
}

resource "local_file" "ssh_config" {
  filename = "${path.module}/ansible/ssh_config"
  content  = <<-EOT
  Host bastion
    HostName ${digitalocean_droplet.bastion.ipv4_address}
    Port 22
    IdentityFile = ../bastion-ssh
    User root

  Host lemmyserver
    HostName ${digitalocean_droplet.lemmy.ipv4_address_private}
    Port 22
    IdentityFile = ../server-ssh
    User root
    ProxyJump bastion
EOT
}
