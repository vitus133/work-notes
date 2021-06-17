FROM registry.fedoraproject.org/f33/python3:latest
USER root
RUN INSTALL_PKGS="tar golang" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all -y && \
    curl -sSLo - https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v4.1.3/kustomize_v4.1.3_linux_amd64.tar.gz | \
	tar xzf - -C /usr/local/bin \


