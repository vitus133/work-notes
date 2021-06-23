#!/usr/bin/python

import os
import shutil
import sys
import json
import yaml
import tempfile
from kubernetes import client, config
from codecs import encode, decode


class SiteApi():
  def __init__(self, namespace="default"):
    self.api = client.CustomObjectsApi()
    self.group="ran.openshift.io"
    self.version="v1alpha1"
    self.namespace=namespace
    self.plural="sites"
    self.watch = True

  def watch_sites(self, rv):
    return self.api.list_namespaced_custom_object_with_http_info(
      group=self.group, version=self.version,
      namespace=self.namespace,
      plural=self.plural, watch=self.watch,
      resource_version=rv, timeout_seconds=5)

class AcmApi():
  pass


class SiteResponseParser():
  def __init__(self, api_response):
    if api_response[1] != 200:
      raise Exception(f"Site API call error: {api_response}")
    else:
      # with tempfile.TemporaryDirectory() as tmpdir:
      self.tmpdir = tempfile.mkdtemp()
      self.del_path = os.path.join(self.tmpdir, 'delete')
      self.del_list = []
      self.upd_path = os.path.join(self.tmpdir, 'update')
      self.upd_list = []
      os.mkdir(self.del_path)
      os.mkdir(self.upd_path)
      self._parse(api_response[0])

      print(self.del_list)
      print(self.upd_list)

      shutil.rmtree(self.tmpdir)

  def _parse(self, resp_data):
    # The response comes in two flavors:
    # 1. For a single object - as a dictionary
    # 2. For several objects - as a text, that must be split to a list
    if type(resp_data) == str and len(resp_data):
      resp_dict = resp_data.split()
      for item in resp_dict:
        self._create_site_file(json.loads(item))
    elif type(resp_data) == dict:
      self._create_site_file(resp_data)
    else:
      pass  # Empty response - no changes

  def _prune_managed_info(self, site:dict):
    site['object']['metadata'].pop("annotations", None)
    site['object']['metadata'].pop("creationTimestamp", None)
    site['object']['metadata'].pop("managedFields", None)
    site['object']['metadata'].pop("generation", None)
    site['object']['metadata'].pop("resourceVersion", None)
    site['object']['metadata'].pop("selfLink", None)
    site['object']['metadata'].pop("uid", None)

  def _create_site_file(self, site: dict):
    self._prune_managed_info(site)
    #print(json.dumps(site, indent=2))
    action = site.get("type")

    if action == "DELETED":
      path, lst = self.del_path, self.del_list
    else:
      path, lst = self.upd_path, self.upd_list

    handle, name = tempfile.mkstemp(dir=path)
    with open(name, 'w') as f:
      yaml.dump(site.get("object"), f)
    lst.append(os.path.join(path, name))


if __name__ == '__main__':
  config.load_incluster_config()
  with open ('/var/run/secrets/kubernetes.io/serviceaccount/namespace', 'r') as ns:
    namespace = ns.read()

  site_api = SiteApi(namespace=namespace)
  resp = site_api.watch_sites(sys.argv[1])
  SiteResponseParser(resp)
