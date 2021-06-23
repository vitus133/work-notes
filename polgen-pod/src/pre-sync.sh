#!/bin/bash

export APISERVER=https://kubernetes.default.svc:443
export TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
export CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
export NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

oc login $APISERVER --token=$TOKEN --certificate-authority=$CACERT &> /dev/null

# Delete old resource version configmap if present
if oc get configmap/rv &> /dev/null; then
    oc delete configmap/rv &> /dev/null
fi

RV=$(curl -s $APISERVER/apis/ran.openshift.io/v1alpha1/namespaces/$NAMESPACE/sites --header "Authorization: Bearer $TOKEN" --cacert $CACERT | jq -rM '.metadata.resourceVersion')

# Store in configmap
if oc create configmap rv --from-literal=sitesResourceVersion=$RV; then
    echo "$(date -R) RAN pre-sync [INFO] Recording RAN sites resourceVersion = $RV" >> /proc/1/fd/1
fi

