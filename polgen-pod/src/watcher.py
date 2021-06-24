#!/usr/bin/python

import os
import shutil
import sys
import json
import yaml
import tempfile
import subprocess
from kubernetes import client, config


class SiteApi():
  def __init__(self):
    self.api = client.CustomObjectsApi()
    self.group="ran.openshift.io"
    self.version="v1"
    self.plural="siteconfigs"
    self.watch = True

  def watch_sites(self, rv):
    return self.api.list_cluster_custom_object_with_http_info(
      group=self.group, version=self.version,
      plural=self.plural, watch=self.watch,
      resource_version=rv, timeout_seconds=5)


class PolicyGenWrapper():
  def __init__(self, paths: list):
    for fl in os.listdir('example-crs'):
      path = os.path.join('example-crs', fl)
      shutil.copy(path, paths[1])


class SiteResponseParser():
  def __init__(self, api_response):
    if api_response[1] != 200:
      raise Exception(f"Site API call error: {api_response}")
    else:
      try:
        # Create temporary file structure for changed site manifests
        self.tmpdir = tempfile.mkdtemp()
        self.del_path = os.path.join(self.tmpdir, 'delete')
        self.del_list = []
        self.upd_path = os.path.join(self.tmpdir, 'update')
        self.upd_list = []
        os.mkdir(self.del_path)
        os.mkdir(self.upd_path)
        self._parse(api_response[0])
        print(f"Sites to delete are: {self.del_list}")
        print(f"Sites to create/update are: {self.upd_list}")

        out_tmpdir = tempfile.mkdtemp()
        out_del_path = os.path.join(out_tmpdir, 'delete')
        out_upd_path = os.path.join(out_tmpdir, 'update')
        os.mkdir(out_del_path)
        os.mkdir(out_upd_path)
        paths = ((self.del_path, out_del_path), 
                (self.upd_path, out_upd_path))
        print(paths)
        for path in paths:
          PolicyGenWrapper(path)

        delete_status = subprocess.run(
          ["oc", "delete", "-f", f"{out_del_path}"],
          stdout=subprocess.PIPE,
          stderr=subprocess.PIPE,
          check=True
        )
        print(delete_status.stdout)

        apply_status = subprocess.run(
          ["oc", "apply", "-f", f"{out_upd_path}"],
          stdout=subprocess.PIPE,
          stderr=subprocess.PIPE
        )
        print(apply_status.stdout)
      except Exception as e:
        print(f"Exception by SiteResponseParser: {e}")
      finally:
        shutil.rmtree(self.tmpdir)
        # shutil.rmtree(out_tmpdir)

  def _parse(self, resp_data):
    # The response comes in two flavors:
    # 1. For a single object - as a dictionary
    # 2. For several objects - as a text, that must be split to a list
    try:
      if type(resp_data) == str and len(resp_data):
        resp_list = resp_data.split('\n')
        items = (x for x in resp_list if len(x) > 0)
        for item in items:
          self._create_site_file(json.loads(item))
      elif type(resp_data) == dict:
        self._create_site_file(resp_data)
      else:
        pass  # Empty response - no changes
    except Exception as e:
      print(f"Exception when parsing API response: {e}")

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
    action = site.get("type")
    if action == "DELETED":
      path, lst = self.del_path, self.del_list
    else:
      path, lst = self.upd_path, self.upd_list
    handle, name = tempfile.mkstemp(dir=path)
    with open(name, 'w') as f:
      yaml.dump(site.get("object"), f)
    lst.append(site.get("object").get("metadata").get("name"))


if __name__ == '__main__':
  config.load_incluster_config()
  site_api = SiteApi()
  resp = site_api.watch_sites(sys.argv[1])
  SiteResponseParser(resp)
