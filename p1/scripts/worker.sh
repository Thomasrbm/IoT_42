#!/usr/bin/env bash
set -euxo pipefail 


SERVER_IP="${SERVER_IP:-192.168.56.110}"
WORKER_IP="${WORKER_IP:-192.168.56.111}"


apt-get update -y || true


echo "Waiting for server token..."
until [ -f /vagrant/shared/node-token ]; do # attend le fichier shared par le serv
  sleep 2
done



# stock le token
K3S_TOKEN="$(cat /vagrant/shared/node-token)"


# k3s mode agent
curl -sfL https://get.k3s.io | \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${K3S_TOKEN}" \
  sh -s - agent \
    --node-ip="${WORKER_IP}" \
    --flannel-iface=eth1



echo "=== K3s worker joined the cluster ==="