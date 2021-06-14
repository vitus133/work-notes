# Creating manifests for the first time #
## Target repo SSH key ##
kubectl create secret generic install-repo-access-key --from-file=git_rsa=../site-defs-converter-image/src/secrets/target_repo_private_key -oyaml
kubectl create secret generic public-key --from-file=git_rsa=../site-defs-converter-image/src/secrets/bitbucket.pub -oyaml

## ArgoCD ##
1. Install to `argocd` namespace
2. Get console secret
3. Login to console
```bash
oc -n argocd port-forward service/example-argocd-server 8443:443
```

