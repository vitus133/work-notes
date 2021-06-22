FROM quay.io/openshift/origin-cli:latest

USER root
RUN INSTALL_PKGS="jq" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all -y && \
    mkdir /usr/src/presync && \
    chown -R 1001:1001 /usr/src/presync
    
# USER 1001
COPY entrypoint.sh /usr/src/presync
WORKDIR /usr/src/presync


