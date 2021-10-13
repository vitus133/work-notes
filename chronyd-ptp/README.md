# README #

This repository provides a set of configurations for the dynamically functioning `chronyd` as described [here](assets/PTP-Chronyd%20interoperability.pdf)

## What is this repository for? ##

It contains a template, source files and a rendering script that creates a valid machineconfig object for applying the configurations above to a Kubernetes cluster. I used Openshift 4.9 single node cluster to verify the resulting behavior.

## How do I get set up? ##
### Prerequisites ###
1. `jinja` CLI for rendering our template. Install from [PyPi](https://pypi.org/project/jinja-cli/)
2. `yq` - Command-line YAML/XML processor. Install from [PyPi](https://pypi.org/project/yq/)
3. `jq` - Command-line JSON processor. Install using a package manager suitable for your platform (E.g. `yum install jq` in my case)
4. `base64` - assume it is already installed on every platform

### Usage ###
Clone the repo, change to `chronyd-ptp` directory and run:
```bash
./render.sh
```

