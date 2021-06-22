#!/bin/bash

export APISERVER=https://kubernetes.default.svc:443
export TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
export CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

curl -s $APISERVER/apis/ran.openshift.io/v1alpha1/namespaces/default/sites --header "Authorization: Bearer $TOKEN" --cacert $CACERT | jq -rM '.metadata.resourceVersion'