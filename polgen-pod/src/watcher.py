#!/usr/bin/python

import os
import shutil
import sys
import json
import yaml
from jinja2 import Template
import tempfile
import subprocess
from kubernetes import client, config
import logging

class Logger():
  @property
  def logger(self):
    name = 'ztp-site-generator.watcher'
    lg = logging.getLogger(name)
    lg.setLevel(logging.DEBUG)
    formatter = logging.Formatter(
        '%(name)s %(asctime)s %(levelname)s [%(module)s:%(lineno)s]: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S %Z')
       
    if not lg.hasHandlers():
        # logging to console
        handler = logging.StreamHandler()
        handler.setLevel(logging.DEBUG)
        handler.setFormatter(formatter)
        lg.addHandler(handler)
    return lg

class SiteApi(Logger):
  def __init__(self):
    try:
      self.api = client.CustomObjectsApi()
      self.group="ran.openshift.io"
      self.version="v1"
      self.plural="siteconfigs"
      self.watch = True
    except Exception as e:
      self.logger.exception(e)

  def watch_sites(self, rv):
    try:
      return self.api.list_cluster_custom_object_with_http_info(
        group=self.group, version=self.version,
        plural=self.plural, watch=self.watch,
        resource_version=rv, timeout_seconds=5)
    except Exception as e:
      self.logger.exception(e)

class PolicyGenWrapper(Logger):
  def __init__(self, paths: list):
    try:
      
      folders = [{'input': paths[0], 'output': paths[1]}]
      cwd = '/usr/src/hook/cnf-features-deploy/ztp/ztp-policy-generator'
      command = 'XDG_CONFIG_HOME=./ kustomize build --enable-alpha-plugins'
      oneliner_file = 'policyGenerator.yaml'
      # Render policyGenerator.yaml template into cwd
      with open('pol_gen.yaml.j2', 'r') as tf:
        t = tf.read()
      tm = Template(t)
      pgy = tm.render(folders=folders)
      with open(os.path.join(cwd, oneliner_file), 'w') as of:
        of.write(pgy)
      self.logger.debug(f"Success writing {cwd}/{oneliner_file}: {pgy}")

      # Run policy generator
      pg_status = subprocess.run(
          command,
          stdout=subprocess.PIPE,
          stderr=subprocess.PIPE,
          check=True,
          cwd=cwd
        )
      self.logger.info(pg_status.stdout)

    except Exception as e:
      self.logger.exception(e)

class SiteResponseParser(Logger):
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
        self.logger.debug(f"Sites to delete are: {self.del_list}")
        self.logger.debug(f"Sites to create/update are: {self.upd_list}")

        out_tmpdir = tempfile.mkdtemp()
        out_del_path = os.path.join(out_tmpdir, 'delete')
        out_upd_path = os.path.join(out_tmpdir, 'update')
        os.mkdir(out_del_path)
        os.mkdir(out_upd_path)
        # Do deletes
        if len(self.del_list) > 0:
          PolicyGenWrapper([self.del_path, out_del_path])
          delete_status = subprocess.run(
            ["oc", "delete", "-f", f"{out_del_path}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True
          )
          self.logger.info(delete_status.stdout)
        
        # Do creates / updates
        if len(self.upd_list) > 0:
          PolicyGenWrapper([self.upd_path, out_upd_path])
          apply_status = subprocess.run(
            ["oc", "apply", "-f", f"{out_upd_path}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
          )
          self.logger.info(apply_status.stdout)
      except Exception as e:
        self.logger.exception(f"Exception by SiteResponseParser: {e}")
      # finally:
      #   shutil.rmtree(self.tmpdir)
      #   shutil.rmtree(out_tmpdir)

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
      self.logger.Exception(f"Exception when parsing API response: {e}")

  def _prune_managed_info(self, site:dict):
    site['object']['metadata'].pop("annotations", None)
    site['object']['metadata'].pop("creationTimestamp", None)
    site['object']['metadata'].pop("managedFields", None)
    site['object']['metadata'].pop("generation", None)
    site['object']['metadata'].pop("resourceVersion", None)
    site['object']['metadata'].pop("selfLink", None)
    site['object']['metadata'].pop("uid", None)

  def _create_site_file(self, site: dict):
    try:
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
    except Exception as e:
      self.logger.exception(e)

if __name__ == '__main__':
  try:
    lg = Logger()
    config.load_incluster_config()
    site_api = SiteApi()
    resp = site_api.watch_sites(sys.argv[1])
    SiteResponseParser(resp)
  except Exception as e:
    lg.logger.exception(e)