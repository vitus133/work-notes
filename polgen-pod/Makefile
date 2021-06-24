# Image URL to use all building/pushing image targets
REG ?= quay.io/vgrinber/ztp-site-generator
all: prod

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build steps
build: ## Build docker image.
	podman build -t ztp-site-generator:latest -f Containerfile
push:	## Push to Quay.io.
	podman push ztp-site-generator:latest ${REG}
debug-addons: ## Include additional files for debugging.
	podman build -t ztp-site-generator:latest -f Containerfile.debug
##@ Make and push
debug: build debug-addons push ## Make and push debug build.
prod: build push ## Make and push production build.

##@ Cluster configuration deployment
deploy: ## Deploy RBAC manifests and RAN Site CRD. TODO: Move top real site crd from ZTP repo.
	oc apply -f hack/clusterrole.yaml -f hack/binding.yaml -f hack/site-crd.yaml

##@ Debug
hack-crd: ## Applies assisted installer, metal3 and hive CRDs. For debug when not having AI and Hive installed on your cluster.
	oc apply -f hack/stub-ai-crd
run: ## Run the debug pod.
	oc apply -f pod.yaml
kill: ## Kill the debug pod.
	oc delete -f pod.yaml
repeat: kill debug run ## Kill running pod, build debug and re-run the pod.

