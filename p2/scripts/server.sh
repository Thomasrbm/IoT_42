set -euxo pipefail

SERVER_IP="${SERVER_IP:-192.168.56.110}"

apt-get update -y
apt-get install -y curl

until ip a show eth1 | grep -q "${SERVER_IP}"; do
  sleep 1
done

curl -sfL https://get.k3s.io | sh -s - server \
  --bind-address="${SERVER_IP}" \
  --advertise-address="${SERVER_IP}" \
  --node-ip="${SERVER_IP}" \
  --flannel-iface=eth1 \
  --write-kubeconfig-mode=644

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

until kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

echo "=== K3s ready ==="

kubectl -n kube-system rollout status deploy/traefik --timeout=180s

for tar in /vagrant/app1/app1-web.tar \
           /vagrant/app2/app2-web.tar \
           /vagrant/app3/app3-web.tar; do
  if [ -f "$tar" ]; then
    k3s ctr images import "$tar"
  fi
done

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f /vagrant/app1/
kubectl apply -f /vagrant/app2/
kubectl apply -f /vagrant/app3/
kubectl apply -f /vagrant/k8s/

kubectl -n dev rollout status deploy/app1 --timeout=180s
kubectl -n dev rollout status deploy/app2 --timeout=180s
kubectl -n dev rollout status deploy/app3 --timeout=180s

echo "=== OK: 3 apps + ingress deployed ==="