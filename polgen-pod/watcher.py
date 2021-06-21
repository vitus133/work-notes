
from kubernetes import client, config
import os
from pprint import pprint

def main():
    srv_acct_root = '/var/run/secrets/kubernetes.io/serviceaccount'
    apiserver = 'https://kubernetes.default.svc'

    with open(os.path.join(srv_acct_root, 'token'), 'r') as t:
      aToken = t.read()

    cacert = os.path.join(srv_acct_root, 'ca.crt')    

    # Create and initialize the configuration object
    aConfiguration = client.Configuration()
    aConfiguration.host = f"{apiserver}:443"
    aConfiguration.verify_ssl = True
    aConfiguration.ssl_ca_cert = cacert
    aConfiguration.api_key = {"authorization": "Bearer " + aToken}

    # Create a ApiClient with our config
    aApiClient = client.ApiClient(aConfiguration)
    api = client.CustomObjectsApi(aApiClient)

    group="ran.openshift.io"
    version="v1alpha1"
    namespace="default"
    plural="sites"
    watch = False

    resp = api.list_namespaced_custom_object(
      group=group, version=version,
      namespace=namespace, plural=plural, watch=watch, timeout_seconds=10)
    
    pprint(resp)

if __name__ == '__main__':
    main()
