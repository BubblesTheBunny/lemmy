#!/usr/bin/env sh

terraform plan -destroy -out destroy.tfplan

terraform apply destroy.tfplan
