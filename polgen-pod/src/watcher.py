#!/usr/bin/python

import os
import sys
import json
from kubernetes import client, config
from codecs import encode, decode

def prune_managed(site:dict):
  site['object']['metadata'].pop("annotations", None)
  site['object']['metadata'].pop("creationTimestamp", None)
  site['object']['metadata'].pop("managedFields", None)
  site['object']['metadata'].pop("generation", None)
  site['object']['metadata'].pop("resourceVersion", None)
  site['object']['metadata'].pop("selfLink", None)
  site['object']['metadata'].pop("uid", None)

def create_site_file(site: dict, sites_path: str=''):
  prune_managed(site)
  print(json.dumps(site, indent=2))
  

def main():
  config.load_incluster_config()
  api = client.CustomObjectsApi()

  group="ran.openshift.io"
  version="v1alpha1"
  namespace="default"
  plural="sites"
  watch = True

  resp = api.list_namespaced_custom_object_with_http_info(
    group=group, version=version,
    namespace=namespace,
    plural=plural, watch=watch, 
    resource_version=sys.argv[1], timeout_seconds=10)
  
  # The response comes in two flavors:
  # 1. For a single object - as a dictionary
  # 2. For several objects - as a text, that must be split to a list
  if type(resp[0]) == str and len(resp[0]):
    resp_dict = resp[0].split()
    for item in resp_dict:
      create_site_file(json.loads(item))
  elif type(resp[0]) == dict:
    create_site_file(resp[0])
  else:
    exit(1) 
if __name__ == '__main__':
    main()
