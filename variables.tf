variable "do_token" {
  type        = string
  description = "The Digital Ocean API Token"
}

variable "environment" {
  type        = string
  description = "Can only be one of: [development, staging, production]"
  default     = "development"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Cloudflare Zone ID"
}

variable "cloudflare_account_id" {
  type        = string
  description = "The CloudFlare Account ID"
}

variable "tunnel_secret" {
  type        = string
  description = "The secret value for the Cloudflare Tunnel"
}

variable "lemmy_version" {
  type        = string
  description = "The version of Lemmy to install"
  default     = "0.17.4"
}

variable "postgres_password" {
  type        = string
  description = "The password for the Postgres DB"
}

variable "domain" {
  type        = string
  description = "The FQDN for your server"
}
