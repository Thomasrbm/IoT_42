#!/usr/bin/env bash

set -euxo pipefail

SERVER_IP="${SERVER_IP:-192.168.56.110}"

apt-get update -y
apt-get install -y curl

# attendre IP interface
until ip a show eth1 | grep -q "${SERVER_IP}"; do
  sleep 1
done

# install K3s
curl -sfL https://get.k3s.io | sh -s - server \
  --bind-address="${SERVER_IP}" \
  --advertise-address="${SERVER_IP}" \
  --node-ip="${SERVER_IP}" \
  --flannel-iface=eth1 \
  --write-kubeconfig-mode=644

# attendre que le service soit UP
until systemctl is-active --quiet k3s; do
  sleep 2
done

# brancher kubectl sur le bon cluster
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# attendre API Kubernetes
until kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

echo "=== K3s server ready ==="