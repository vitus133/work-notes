#!/bin/bash
set -e

#root_dir=$(dirname $(dirname $(realpath $0)))
if [ -f $ZIP_NAME ]; then
  rm -f $ZIP_NAME
fi

if [ -f deployment/site-config-crd.y*ml ]; then
  rm -f deployment/site-config-crd.y*ml
fi

sites=( hack/example-sites/*.y*ml )
if (( ${#sites[@]} )); then
  rm -f hack/example-sites/*.y*ml
fi
