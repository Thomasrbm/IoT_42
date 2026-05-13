#!/usr/bin/env bash

set -euxo pipefail

CLUSTER_NAME="mycluster"
ARGOCD_NS="argocd"
GITLAB_NS="gitlab"
APP_NS="dev"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_MANIFEST="$SCRIPT_DIR/../confs/argocd-application.yaml"


if k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}\b"; then
  echo "Cluster '${CLUSTER_NAME}' deja existant, skip creation."
else
  echo "Creation du cluster k3d '${CLUSTER_NAME}'..."
  k3d cluster create "${CLUSTER_NAME}" \
    --api-port 6443 \
    -p "8888:80@loadbalancer" \
    -p "8443:443@loadbalancer" \
    --agents 0
fi

#     -p "8888:80@loadbalancer" \  
# quand qq demande localhoste sur la vm envoit la requete GET a port 80 du  ingress 

# -p "8443:443@loadbalancer" \
# pareil mais pour https


kubectl get namespace "${GITLAB_NS}" >/dev/null 2>&1 || \
  kubectl create namespace "${GITLAB_NS}"

GITLAB_OMNIBUS_MANIFEST="$SCRIPT_DIR/../confs/omnibus.yaml"
GITLAB_MANIFEST="$SCRIPT_DIR/../confs/gitlab.yaml"
echo "Installation Gitlab dans le namespace '${GITLAB_NS}'..."
# IMPORTANT : ConfigMap d abord, sinon le pod demarre sans la config
kubectl apply -f "${GITLAB_OMNIBUS_MANIFEST}"
kubectl apply -f "${GITLAB_MANIFEST}"


echo "Attente que GitLab soit READY (3-5 min au 1er boot)..."
kubectl -n "${GITLAB_NS}" rollout status deploy/gitlab --timeout=1200s

echo "Attente que Rails reponde..."
for i in $(seq 1 60); do
  if kubectl -n "${GITLAB_NS}" exec deploy/gitlab -- \
       gitlab-rails runner 'puts :ok' 2>/dev/null | grep -q ok; then
    echo "  Rails OK"
    break
  fi
  echo "  ... essai ${i}/60"
  sleep 10
done


# cree le repo en public sur root user
echo "Creation du projet root/iot-app (public) dans GitLab..."
kubectl -n "${GITLAB_NS}" exec deploy/gitlab -- gitlab-rails runner "
  user = User.find_by_username('root')
  unless Project.find_by_full_path('root/iot-app')
    Projects::CreateService.new(
      user,
      name: 'iot-app',
      path: 'iot-app',
      visibility_level: Gitlab::VisibilityLevel::PUBLIC
    ).execute
  end
"


# cree un pod temp pour clone et push vers le namespace gitlab depuis github
echo "Clone du repo source GitHub + push vers GitLab local..."
kubectl run gitlab-init-push --rm -i --restart=Never \
  --image=alpine/git:latest \
  --namespace="${GITLAB_NS}" \
  --command -- sh -c '
    set -e
    git clone https://github.com/Thomasrbm/IoT_Watched_by_ArgoCD_42.git /tmp/src
    cd /tmp/src
    git remote add gitlab http://root:changeme123@gitlab.gitlab.svc.cluster.local/root/iot-app.git
    git push gitlab HEAD:main --force
  '

echo "=== GitLab pret + projet iot-app peuple ==="



kubectl get namespace "${ARGOCD_NS}" >/dev/null 2>&1 || \
  kubectl create namespace "${ARGOCD_NS}"





echo "Installation ArgoCD dans le namespace '${ARGOCD_NS}'..."
kubectl apply --server-side --force-conflicts -n "${ARGOCD_NS}" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml



echo "Attente des pods ArgoCD (peut prendre 1-2 minutes)..."
for deploy in argocd-server argocd-repo-server argocd-redis \
              argocd-dex-server argocd-applicationset-controller; do
  kubectl wait --for=condition=available --timeout=300s \
    -n "${ARGOCD_NS}" "deployment/${deploy}" || true
done

kubectl rollout status -n "${ARGOCD_NS}" statefulset/argocd-application-controller \
  --timeout=300s \
  || { echo "[ERROR] argocd-application-controller not Ready apres 300s -> abort"; exit 1; }



echo "Apply de l Application ArgoCD (${APP_MANIFEST})..."
kubectl apply -f "${APP_MANIFEST}"


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
