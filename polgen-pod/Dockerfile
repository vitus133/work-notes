FROM registry.fedoraproject.org/f33/python3:latest
USER root
RUN INSTALL_PKGS="golang" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all -y

