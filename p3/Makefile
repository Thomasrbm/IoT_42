CLUSTER_NAME := mycluster
ARGOCD_NS    := argocd
APP_NS       := dev
SCRIPT_DIR   := $(CURDIR)/scripts
APP_MANIFEST := $(CURDIR)/confs/argocd-application.yaml
PF_PID       := /tmp/p3-argocd-pf.pid
PF_LOG       := /tmp/p3-argocd-pf.log

up:
	@bash $(SCRIPT_DIR)/install_p3_req.sh
	@if docker info >/dev/null 2>&1; then \
		bash $(SCRIPT_DIR)/deploy_argocd.sh; \
	else \
		echo ">>> Groupe docker pas actif dans la session -> relance via sg docker"; \
		sg docker -c "bash $(SCRIPT_DIR)/deploy_argocd.sh"; \
	fi
	@# kill un eventuel port-forward precedent puis relance en background
	@if [ -f $(PF_PID) ]; then kill $$(cat $(PF_PID)) 2>/dev/null || true; rm -f $(PF_PID); fi
	@nohup kubectl port-forward -n $(ARGOCD_NS) svc/argocd-server 8080:443 > $(PF_LOG) 2>&1 & echo $$! > $(PF_PID)
	@sleep 1
	@echo ""
	@echo "================================================================"
	@echo "                    P3 PRET A L EMPLOI"
	@echo "================================================================"
	@echo ""
	@echo "  App iot-app   : http://localhost:8888"
	@echo "                  (direct via Ingress + Traefik)"
	@echo ""
	@echo "  ArgoCD UI     : https://localhost:8080"
	@echo "    login       : admin"
	@echo "    password    : $$(kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	@echo ""
	@echo "    [Cert self-signed sur localhost = warning navigateur normal :"
	@echo "     cliquer 'Avance' -> 'Continuer vers localhost (non securise)']"
	@echo ""
	@echo "  Verifier      : kubectl get pods -A"
	@echo "                  kubectl get application -n $(ARGOCD_NS)"
	@echo ""
	@echo "  Test GitOps   : push v1->v2 dans deployment.yaml du repo"
	@echo "                  throbert_IoT_Watched_by_ArgoCD_42, ArgoCD redeploiera auto."
	@echo ""
	@echo "================================================================"

down:
	@if [ -f $(PF_PID) ]; then kill $$(cat $(PF_PID)) 2>/dev/null || true; rm -f $(PF_PID); fi
	-k3d cluster stop $(CLUSTER_NAME)

clean:
	-kubectl delete -f $(APP_MANIFEST) --ignore-not-found
	-kubectl delete namespace $(APP_NS) --ignore-not-found

fclean:
	@if [ -f $(PF_PID) ]; then kill $$(cat $(PF_PID)) 2>/dev/null || true; rm -f $(PF_PID); fi
	-k3d cluster delete $(CLUSTER_NAME)

re: fclean up


.PHONY: up down clean fclean re
