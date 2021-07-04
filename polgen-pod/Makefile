# Image URL to use all building/pushing image targets
# Note - you must be logged in. Do `podman login -u ... -p ... quay.io` before pushing images
# To get push permission, email to <globalcustomerservice@redhat.com>:
# Subject: Quay.io Employee access request
# - Name, Surname:
# <Your name and surname>
# - Quay.io username:
# <your quay.io username>
# - Email address that your Quay.io username is linked to (it must have @redhat domain):
# <your Red Hat email>
# - Specify the type of your request:
# Type 1
REG ?= quay.io/redhat_emp1/ztp-site-generator


# The link to download cnf-features-deploy as a zip file. 
# TODO: Change the way policy gen code is pulled after moving to the final repo
REPO_ZIP_LINK ?= https://github.com/serngawy/cnf-features-deploy/archive/refs/heads/gitOps.zip
REPO_ZIP_NAME ?= gitOps.zip

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
get_ztp: ## Download ZTP zip from github
	[ ! -f ${REPO_ZIP_NAME} ] && wget ${REPO_ZIP_LINK}

samples: # Copy site CRD and psamples from ZTP zip
	unzip ${REPO_ZIP_NAME} -x */vendor/* -x */cnf-tests/* -x */tools/* -x */openshift-ci/* -x */hack/* && \
	mv cnf-features-deploy* cnf-features-deploy && \
	cp cnf-features-deploy/ztp/ran-site-plan-crd/site-config-crd.yaml deployment/ &&\
	cp cnf-features-deploy/ztp/ztp-policy-generator/siteConfigExamples/* hack/example-sites/ && \
	rm -rf cnf-features-deploy

build_image: ## Build docker image.
	podman build -t ztp-site-generator:latest -f Containerfile
push_image:	## Push to Quay.io.
	podman push ztp-site-generator:latest ${REG}
clean: ## Remove the cnf-features-deploy zip and clean site CRDs and site examples
	ZIP_NAME=${REPO_ZIP_NAME} hack/clean.sh

##@ Make and push
prod: clean get_ztp samples build_image push_image ## Make and push production build.

##@ Cluster configuration deployment
deploy: ## Deploy RBAC manifests and RAN Site CRD.
	oc apply -f deployment
undeploy: ## Undeploy RBAC manifests and RAN Site CRD.
	oc delete -f deployment
##@ Debug
hack-crd: ## Applies assisted installer, metal3 and hive CRDs. For debug when not having AI and Hive installed on your cluster.
	oc apply -f hack/stub-ai-crd
unhack-crd: ## Removes assisted installer, metal3 and hive CRDs. For debug when not having AI and Hive installed on your cluster.
	oc apply -f hack/stub-ai-crd
run: ## Run the debug pod.
	oc apply -f pod.yaml && \
	oc wait --for=condition=ready --timeout=60s pod/ztp-site-generator
kill: ## Kill the debug pod.
	oc delete -f pod.yaml
repeat: kill build_image push_image run shell ## Kill running pod, build, re-run the pod and get a shell to the pod
shell: ## Open a shell into the running pod
	oc exec -it ztp-site-generator -- /bin/bash

