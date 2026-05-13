#!/usr/bin/env bash

set -euxo pipefail

SERVER_IP="${SERVER_IP:-192.168.56.110}"

apt-get update -y
apt-get install -y curl

# attendre IP interface
until ip a show eth1 | grep -q "${SERVER_IP}"; do
  sleep 1
done

# flannel = plugin reseau CNI de k3s. relie les pods en reseau (proxy)
# et permet a l ingress d aller vers l exterieur.
# --flannel-iface=eth1 -> on force flannel a passer par le reseau prive
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

# attendre que traefik (ingress controller embarque par k3s) soit pret
until kubectl -n kube-system get deploy traefik >/dev/null 2>&1; do
  sleep 2
done
kubectl -n kube-system rollout status deploy/traefik --timeout=180s

# importer les images Docker (.tar) dans containerd de k3s
# imagePullPolicy: Never -> k3s doit trouver l image en local
for tar in /vagrant/app1/app1-web.tar \
           /vagrant/app2/app2-web.tar \
           /vagrant/app3/app3-web.tar; do
  k3s ctr images import "${tar}"
done

# creer le namespace "dev" utilise par tous les manifestes
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# deployer les 3 apps + leurs services + l ingress
kubectl apply -f /vagrant/app1/app1.yaml
kubectl apply -f /vagrant/app1/app1-service.yaml
kubectl apply -f /vagrant/app2/app2.yaml
kubectl apply -f /vagrant/app2/app2-service.yaml
kubectl apply -f /vagrant/app3/app3.yaml
kubectl apply -f /vagrant/app3/app3-service.yaml
kubectl apply -f /vagrant/k8s/ingress.yaml

# attendre que les 3 deployments soient prets
kubectl -n dev rollout status deploy/app1 --timeout=180s
kubectl -n dev rollout status deploy/app2 --timeout=180s
kubectl -n dev rollout status deploy/app3 --timeout=180s

echo "=== Cluster pret : 3 apps deployees + ingress ==="
