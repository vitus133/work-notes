FROM registry.fedoraproject.org/f33/python3:latest

USER root
# RUN INSTALL_PKGS="tar golang" && \
#     yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
#     rpm -V $INSTALL_PKGS && \
#     yum clean all -y && \
#     curl -sSLo - https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v3.8.8/kustomize_v3.8.8_linux_amd64.tar.gz | \
# 	tar xzf - -C /usr/local/bin
    
RUN pip install --upgrade pip && \
    pip install kubernetes && \
    mkdir /usr/src/policy-gen && \
    chown -R 1001:1001 /usr/src/policy-gen
USER 1001
# COPY cnf-features-deploy/ztp/ /usr/src/policy-gen

COPY watcher.py /usr/src/policy-gen
WORKDIR /usr/src/policy-gen


