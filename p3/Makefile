CLUSTER_NAME := mycluster
APP_NS       := dev
SCRIPT_DIR   := $(CURDIR)/scripts
APP_MANIFEST := $(CURDIR)/confs/argocd-application.yaml

.PHONY: up down clean fclean re

up:
	@bash $(SCRIPT_DIR)/install.sh
	@bash $(SCRIPT_DIR)/setup.sh

down:
	-k3d cluster stop $(CLUSTER_NAME)

clean:
	-kubectl delete -f $(APP_MANIFEST) --ignore-not-found
	-kubectl delete namespace $(APP_NS) --ignore-not-found

fclean:
	-k3d cluster delete $(CLUSTER_NAME)

re: fclean up
