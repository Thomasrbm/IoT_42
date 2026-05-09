#!/usr/bin/env bash
set -euxo pipefail # -e quitte si plante
                   # -u erreur si var non def
                   # -x affiche du debug
                   # -o pipefail propage erreur dans le pipe


if command -v docker >/dev/null 2>&1; then
  echo "Docker deja installe : $(docker --version)"
else
  echo "Installation de Docker..."
  # -fsSL : -f fail si erreur, -s silent, -S montre erreur  quand meme mais pas le reste
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  rm /tmp/get-docker.sh
fi


# ========= Ajouter user au groupe docker 
# Sans ca il faut sudo a chaque commande docker
#  groupe "docker" donne acces au socket /var/run/docker.sock
#  getent verifie que le groupe existe avant d ajouter (sinon erreur)
if getent group docker >/dev/null; then
  if ! groups "$USER" | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER"
    echo ""
    echo "ajout du USER groupe docker."
  fi
fi



# ================ Demarrer systmctl Docker  service + auto activ
# car parfois pas d auto start
if ! systemctl is-active --quiet docker; then
  sudo systemctl start docker
  sudo systemctl enable docker # auto-start au boot
fi



# ====================== Verifier que kubectl + k3d sont la
# Si manquants -> on previent l user, on n installe pas en double
MISSING=""
command -v kubectl >/dev/null 2>&1 || MISSING="$MISSING kubectl"
command -v k3d     >/dev/null 2>&1 || MISSING="$MISSING k3d"

if [ -n "$MISSING" ]; then
  echo ""
  echo "Outils manquants :$MISSING"
  echo "  -> lance d abord ../../install_iot.sh a la racine du projet IoT_42"
  exit 1
fi




echo ""
echo "=========================================="
echo " Pre-requis P3 OK"
echo "=========================================="
echo " docker  : $(docker --version)"
echo " kubectl : $(kubectl version --client --output=yaml | grep gitVersion | head -1 | awk '{print $2}')"
echo " k3d     : $(k3d --version | head -1)"
echo ""
echo "Etape suivante : ./setup.sh"
