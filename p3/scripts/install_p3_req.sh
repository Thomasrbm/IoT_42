#!/usr/bin/env bash
# install_p3_req.sh - installe les pre-requis P3 (Docker + kubectl + k3d)
# Idempotent : peut etre relance, n installe que ce qui manque

set -euxo pipefail # -e quitte si plante / -u erreur si var non def
                   # -x affiche debug   / -o pipefail propage erreur dans pipe

# ====== Versions des outils K8s (alignees avec install_iot.sh racine)
KUBECTL_VERSION="v1.31.0"
K3D_VERSION="v5.7.4"
INSTALL_DIR="/usr/local/bin"
TMP_DIR="/tmp"



# ===================== 1. Docker
if command -v docker >/dev/null 2>&1; then
  echo "Docker deja installe : $(docker --version)"
else
  echo "Installation de Docker..."
  # -fsSL : fail si erreur, silent, montre erreur quand meme
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  rm /tmp/get-docker.sh
fi

# Ajouter le user au groupe docker (sinon sudo a chaque cmd docker)
# getent verifie que le groupe existe avant d ajouter
if getent group docker >/dev/null; then
  if ! groups "$USER" | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER"
    echo "ajout du USER au groupe docker."
  fi
fi

# Demarrer le service docker + auto-start au boot
if ! systemctl is-active --quiet docker; then
  sudo systemctl start docker
  sudo systemctl enable docker
fi



# ===================== 2. kubectl (binaire dans /usr/local/bin)
if command -v kubectl >/dev/null 2>&1; then
  echo "kubectl deja installe : $(kubectl version --client --output=yaml | grep gitVersion | head -1 | awk '{print $2}')"
else
  echo "Installation de kubectl ${KUBECTL_VERSION}..."
  curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o "${TMP_DIR}/kubectl"
  sudo install -m 0755 "${TMP_DIR}/kubectl" "${INSTALL_DIR}/kubectl"
  rm -f "${TMP_DIR}/kubectl"
fi



# ===================== 3. k3d (binaire dans /usr/local/bin)
if command -v k3d >/dev/null 2>&1; then
  echo "k3d deja installe : $(k3d --version | head -1)"
else
  echo "Installation de k3d ${K3D_VERSION}..."
  curl -fsSL "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-amd64" -o "${TMP_DIR}/k3d"
  sudo install -m 0755 "${TMP_DIR}/k3d" "${INSTALL_DIR}/k3d"
  rm -f "${TMP_DIR}/k3d"
fi



echo ""
echo "=========================================="
echo " Pre-requis P3 OK"
echo "=========================================="
echo " docker  : $(docker --version)"
echo " kubectl : $(kubectl version --client --output=yaml | grep gitVersion | head -1 | awk '{print $2}')"
echo " k3d     : $(k3d --version | head -1)"
echo ""
echo "Etape suivante : ./deploy_argocd.sh"
