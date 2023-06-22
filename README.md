# Welcome!

This is Infrastructure as Code using Terraform and Ansible to run a simple, idempotent way to spin up a Lemmy Instance

## Getting Started

Requirements:
* [DigitalOcean account](https://www.digitalocean.com/)
* [A Domain on Cloudflare](https://www.cloudflare.com/)

## Volumes

Volumes are created through a distinct path to allow ripping apart
the infrastructure without losing any data. [volumes](./volumes)

## Example

To populate the required environment variables I use a `.secrets` and a `.tunnel` file

example `.secrets`

```shell
export TF_VAR_do_token=<your digital ocean api token]
export CLOUDFLARE_API_TOKEN=<your cloudflare api token>
export TF_VAR_cloudflare_zone_id=<your cloudflare zone id>
export TF_VAR_cloudflare_account_id=<your cloudflare account id>
export TF_VAR_environment=development
export TF_VAR_postgres_password=<your postgres password>
```

example `.tunnel`

```shell
export TF_VAR_tunnel_secret=`hexdump -vn32 -e'4/4 "%08X"' /dev/urandom | base64 -w0 -`
```

```shell
export TF_VAR_domain=<your domain>
source ./.secrets
source ./.tunnel
cd volumes
./run.sh
cd -
./run.sh
```

## Cloudflare

The API token needs "Account.Cloudflare Tunnel" and "Zone.DNS" edit privs.