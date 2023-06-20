#!/usr/bin/env sh

export TF_IN_AUTOMATION=true

ssh-keygen -t ed25519 -N "" -f server-ssh -C "root@lemmy"
ssh-keygen -t ed25519 -N "" -f bastion-ssh -C "root@bastion"

terraform init || exit

terraform fmt -recursive || exit

terraform validate || exit

terraform plan -out do.tfplan || exit

terraform apply do.tfplan || exit

cd ansible || exit

echo "Waiting for droplets"

sleep 30

./run.sh

cd - || exit
