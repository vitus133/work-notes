#!/bin/bash

. $(dirname "$0")/common.sh

CM=$(oc get configmap/rv &> /dev/null)
if (( $? == 0 )); then
  RV=$( oc get configmap/rv -ojson | jq -rM '.metadata.resourceVersion' )
  echo "$(date -R) RAN post-sync [INFO] Retrieved RAN sites resourceVersion $RV" >> /proc/1/fd/2
  echo $RV
else
  echo "$(date -R) RAN post-sync [ERROR] Failed to get RAN sites resourceVersion" >> /proc/1/fd/2
  echo "0"
fi
