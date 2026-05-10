#!/usr/bin/env bash


# cree le cluster k3d, install ArgoCD, co l App sur GitHub.

# etapes :
#  1) k3d cree un container docker rancher/k3s (= 1 noeud K8s "tout-en-un")
#  2) On cree un namespace "argocd" (separation logique des pods systeme argo)
#  3) On apply le manifest officiel ArgoCD => ~7 pods se lancent dans argocd
#  4) On attend que tous les pods argocd soient Ready
#  5) On apply notre Application => ArgoCD cree le namespace "dev" et
#     deploie iot-app dedans en pullant deployment.yaml + service.yaml depuis
#     le repo GitHub IoT_Watched_by_ArgoCD_42
#  6) On apply l Ingress qui route localhost:8888/ vers svc/iot-app
#     (le recap final + port-forward ArgoCD est gere par le Makefile)

set -euxo pipefail

# ====== Variables 
CLUSTER_NAME="mycluster"      # nom du cluster k3d (voir avec cmd 'k3d cluster list')
ARGOCD_NS="argocd"            # namespaces
APP_NS="dev"

# $(dirname "$0") = dossier ou se trouve ce script 

# SCRIPT_DIR=/home/throbert/Desktop/Code/IoT_42/p3/scripts
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" # pwd pour afficher et donner la sortie a APP MANIFEST
# cd uniquement pour pouvoir pwd

# APP_MANIFEST=/home/throbert/Desktop/Code/IoT_42/p3/scripts/../confs/argocd-application.yaml
APP_MANIFEST="$SCRIPT_DIR/../confs/argocd-application.yaml"



# =============== 1. Creer le cluster k3d 
# k3d cluster list  : affiche tous les clusters k3d existants
# grep -q ^CLUSTER_NAME$    : -q silent, ^$ = debut et fin, ancres pour match exact (pas substring)
if k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}\b"; then
  echo "Cluster '${CLUSTER_NAME}' deja existant, skip creation."
else
  echo "Creation du cluster k3d '${CLUSTER_NAME}'..."
  # --api-port 6443      : port standard de l API K8s (kubectl va la-dessus)
  # -p "8888:80@loadbalancer"  gauche hote, droite cluster
  # loadbalancer = k3d lance par defaut : k3d-mycluster-server-0 (node server+worker) 
  #                                       k3d-mycluster-server-0 (proxy nginx, entrypoint unique)   : fait le pont entre hote et cluster

  # --agents 0           : pas de noeud worker separe, tout sur le server
  #                        (control-plane + worker dans le meme container)
  k3d cluster create "${CLUSTER_NAME}" \
    --api-port 6443 \
    -p "8888:80@loadbalancer" \
    --agents 0
fi



# ============== 2. Namespace argocd 
# get ns argocd : si existe -> code 0, sinon code 1
#               : on enchaine sur create seulement si get a fail avec le ==> "||"
kubectl get namespace "${ARGOCD_NS}" >/dev/null 2>&1 || \
  kubectl create namespace "${ARGOCD_NS}"



# ============= 3. Install ArgoCD
# Manifest officiel = ~50 ressources (Deployments, Services, ConfigMaps, RBAC, CRDs)
# -n argocd : tout va dans le namespace argocd
# stable    : derniere version stable taggee par le projet ArgoCD
# -f  :  fetch url

# de base kubectl apply est client side et stock une copie du yaml dans kubectl.kubernetes.io/last-applied-configuration
# mais argocd a des objets enorme et full la anotation d un coup



# --server-side : evite l erreur "metadata.annotations: Too long"
#   applicationsets.argoproj.io 

# --------------------------

# en server side l api retient qui modif quoi (quelle ligne du yaml (plutot "champs" = indentation))
# kubectl quand on fait apply
# argocd etc,

# le champs est au modificateur

# si un autre service modif le champ y a conflit 

# --force-conflicts : modifie quand meme
echo "Installation ArgoCD dans le namespace '${ARGOCD_NS}'..."
kubectl apply --server-side --force-conflicts -n "${ARGOCD_NS}" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml



# ====================== 4. Attendre que ArgoCD soit pret
# deploit les pods argoCD

# wait --for=condition=available : bloque jusqu a ce que le Deployment ait
# le minimum de replicas Ready (sinon le apply de l Application va planter
# car les CRDs argo ne sont peut etre pas encore enregistres dans l API)
#
# On attend les 5 deployments cles d ArgoCD :
echo "Attente des pods ArgoCD (peut prendre 1-2 minutes)..."
for deploy in argocd-server argocd-repo-server argocd-redis \
              argocd-dex-server argocd-applicationset-controller; do
  kubectl wait --for=condition=available --timeout=300s \
    -n "${ARGOCD_NS}" "deployment/${deploy}" || true
  # || true = si le deploy n existe pas dans cette version d argocd on skip   [pour pas block infini]
done

# statfull check si tout : for deploy in argocd-server argocd-repo-server argocd-redis \
#              argocd-dex-server argocd-applicationset-controller;

# sinon timout = script plante
kubectl rollout status -n "${ARGOCD_NS}" statefulset/argocd-application-controller \
  --timeout=300s \
  || { echo "[ERROR] argocd-application-controller not Ready apres 300s -> abort"; exit 1; }



# ====================== 5. Apply notre Application
# applique le manifest dans conf pour watch le repo github
echo "Apply de l Application ArgoCD (${APP_MANIFEST})..."
kubectl apply -f "${APP_MANIFEST}"


# ====================== 6. Ingress iot-app
# une fois apply fait on appel ingress pour avoir les routes d acces. 
INGRESS_MANIFEST="$SCRIPT_DIR/../confs/iot-app-ingress.yaml"
echo "Attente du service iot-app dans le namespace ${APP_NS}..."
for i in $(seq 1 60); do
  if kubectl get svc -n "${APP_NS}" iot-app >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
echo "Apply de l Ingress iot-app (${INGRESS_MANIFEST})..."
kubectl apply -f "${INGRESS_MANIFEST}"



echo ""
echo "Setup K8s termine. Le Makefile lance le port-forward ArgoCD"
echo "et affiche les URLs / mot de passe juste apres."
