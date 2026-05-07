#!/usr/bin/env bash
set -euxo pipefail  # -e quitte si plante
                    # -u erreur si var non def
                    # -x affiche du debug
                    # -o pipefail, propage erreur dans le pipe



SERVER_IP="${SERVER_IP:-192.168.56.110}" # use server ip sinon fall back sur ip de droite




apt-get update -y || true # maj packet si erreur true skip l erreur
apt-get install -y curl 



# Attendre que eth1 soit prête avec la bonne IP
echo "Waiting for eth1 to be ready..."
until ip a show eth1 | grep -q "${SERVER_IP}"; do
  sleep 1
done



# isntall k3s
curl -sfL https://get.k3s.io | sh -s - server \
  --bind-address="${SERVER_IP}" \
  --advertise-address="${SERVER_IP}" \
  --node-ip="${SERVER_IP}" \
  --flannel-iface=eth1 \
  --write-kubeconfig-mode=644 #pas oblig, pratique en dev
# -s silent, -f failt sur erreur, L suit les redirections
# | sh -s - = pipe vers sh
# server, mode.

# ip d ecoute k3s
# advertise a tout les node en broadcass : "contactez moi ici"
# identite precise du node server
# flannel force interface eth1 (suj), par defaut 0
# rend le  /etc/rancher/k3s/k3s.yaml (fichier config)  lisible sans sudo



# install en 10sec mais setup plus long, donc sleep jusqu a pret
echo "Waiting for K3s to be ready..."
until kubectl get nodes >/dev/null 2>&1; do # redirection silencie le stdout
  sleep 2                                   # 2&1 pour stderr fait comme stdout
done



mkdir -p /vagrant/shared  # dossier partager entre les vms
cp /var/lib/rancher/k3s/server/node-token /vagrant/shared/node-token # copie token du node
chmod 644 /vagrant/shared/node-token




# copie le fichier config dans shared pour pouvoir use kubectl.
cp /etc/rancher/k3s/k3s.yaml /vagrant/shared/k3s.yaml
sed -i "s/127.0.0.1/${SERVER_IP}/g" /vagrant/shared/k3s.yaml # remplace localhoste par ip reel du server
chmod 644 /vagrant/shared/k3s.yaml



echo "=== K3s server ready ==="
kubectl get nodes # 