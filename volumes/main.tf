terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~>2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_volume" "postgres" {
  name                     = "postgres"
  region                   = "nyc3"
  size                     = 100
  initial_filesystem_type  = "ext4"
  initial_filesystem_label = "postgres"
}

resource "digitalocean_volume" "pictrs" {
  name                     = "pictrs"
  region                   = "nyc3"
  size                     = 100
  initial_filesystem_type  = "ext4"
  initial_filesystem_label = "pictrs"
}

resource "digitalocean_volume" "lemmy_ui" {
  name                     = "lemmyui"
  region                   = "nyc3"
  size                     = 10
  initial_filesystem_type  = "ext4"
  initial_filesystem_label = "lemmy-ui"
}
