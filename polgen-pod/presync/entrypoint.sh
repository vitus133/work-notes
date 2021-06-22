#!/bin/bash

export APISERVER=https://kubernetes.default.svc:443
export TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
export CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
oc login $APISERVER --token=$TOKEN --certificate-authority=$CACERT &> /dev/null
oc delete configmap/rv &> /dev/null
RV=$(curl -s $APISERVER/apis/ran.openshift.io/v1alpha1/namespaces/default/sites --header "Authorization: Bearer $TOKEN" --cacert $CACERT | jq -rM '.metadata.resourceVersion')
echo "Recording RAN sites resourceVersion = $RV"
oc create configmap rv --from-literal=sitesResourceVersion=$RV
