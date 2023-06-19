#!/usr/bin/env sh

terraform init || exit

terraform fmt -recursive || exit

terraform validate || exit

terraform plan -out do.tfplan || exit

terraform apply do.tfplan || exit
