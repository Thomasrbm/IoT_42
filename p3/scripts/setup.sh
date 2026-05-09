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
#  6) On affiche le mot de passe admin + comment se connecter a l UI

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
echo "Installation ArgoCD dans le namespace '${ARGOCD_NS}'..."
kubectl apply -n "${ARGOCD_NS}" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml



# ====================== 4. Attendre que ArgoCD soit pret
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



# ====================== 6. Recap + acces UI
# Le mot de passe admin initial est dans un secret K8s genere au boot
# data.password est encode en base64, on decode pour l afficher

# cmd pour get tout les secret info du ns :  get secret argocd-initial-admin-secret

# -n pour namespace
# -o pour format output en json ici
# .data.password extrait que le mdp

#  2>/dev/null stderr vers la trash
#  base64 -d   decode le mdp base 64 en claire  
ADMIN_PWD=$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "(mdp does not exist)")

echo ""
echo "=========================================="
echo " Setup termine !"
echo "=========================================="
echo ""
echo "ArgoCD UI :"
echo "  kubectl port-forward -n ${ARGOCD_NS} svc/argocd-server 8080:443"
echo "  -> https://localhost:8080  (login: admin / pwd: ${ADMIN_PWD})"
echo ""
echo "App iot-app (apres sync d ArgoCD) :"
echo "  kubectl port-forward -n ${APP_NS} svc/iot-app 8888:80"
echo "  -> http://localhost:8888"
echo ""
echo "Verifier l etat :"
echo "  kubectl get pods -n ${ARGOCD_NS}"
echo "  kubectl get pods -n ${APP_NS}"
echo "  kubectl get application -n ${ARGOCD_NS}"
echo ""
echo "Pour declencher un sync ArgoCD : push v1->v2 dans deployment.yaml"
echo "du repo IoT_Watched_by_ArgoCD_42, ArgoCD detectera le commit"
echo "et redeploiera automatiquement (selfHeal + automated)."
