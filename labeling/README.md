# Node auto-labelling

## Why
When OCP worker node is created, it automatically joins the `worker` machine config pool. If we want it to be in a custom pool, we must label the node. The machine config operator will then detect the change and join the node to the pool, which will lead to a reboot.
If we want to eliminate this reboot, we should make the node joining the correct machine config pool from the beginning by labeling it accordingly before the first boot.

## How
[Kubelet](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/) documentation describes the `--node-labels` argument, that we can leverage to apply a custom labeling:

>--node-labels mapStringString
>>	<Warning: Alpha feature>Labels to add when registering the node in the cluster. Labels must be `key=value pairs` separated by `,`. Labels in the `kubernetes.io` namespace must begin with an allowed prefix (`kubelet.kubernetes.io`, `node.kubernetes.io`) or be in the specifically allowed set (`beta.kubernetes.io/arch`, `beta.kubernetes.io/instance-type`, `beta.kubernetes.io/os`, `failure-domain.beta.kubernetes.io/region`, `failure-domain.beta.kubernetes.io/zone`, `kubernetes.io/arch`, `kubernetes.io/hostname`, `kubernetes.io/os`, `node.kubernetes.io/instance-type`, `topology.kubernetes.io/region`, `topology.kubernetes.io/zone`)

Setting this argument before the node registration will do the trick, but MCO (Machine Config Operator), that is configuring the kubelet, does not provide an API for that. MCO also prohibits direct changes to the kubelet configuration, rendering the node "Degraded" if any mutations happen to `kubelet.service` systemd unit or anything else MCO configures.

### Systemd drop-ins
Kubelet runs on a node as a `systemd` unit. We are going to use one of system daemon features called `drop-in`, as described in [systemd.unit — Unit configuration](https://www.freedesktop.org/software/systemd/man/systemd.unit.html):
>Along with a unit file foo.service, a "drop-in" directory foo.service.d/ may exist. All files with the suffix ".conf" from this directory will be parsed after the unit file itself is parsed. This is useful to alter or add configuration settings for a unit, without having to modify unit files.

### Leveraging drop-ins for node labeling
Here we overlay the kubelet.service and add a label using a drop-in. Our drop-in will do following tricks when systemd unit (re)starts:
- Read `ExecStart` directive from the existing kubelet.service unit
- Isolate the --node-labels argument
- Add the custom label, if configured.
  - The intention here to add the drop-in to all worker nodes, as an infrastructure, but configure custom label only on the designated custom pool nodes
- Execute the original ExecStart directive including the additional label

This idea and implementation are inspired by this work:
https://github.com/lack/redhat-notes/tree/main/crio_unshare_mounts 

### The drop-in source files
- [extractExecStart](src/extractExecStart) - A script that extracts the contents of the first ExecStart stanza from the given systemd unit. Copied to /usr/local/bin on the node
- [addExtraLabels](src/addExtraLabels) - A script that adds label(s) defined in the `FIRST_BOOT_ONLY_KUBELET_NODE_EXTRA_LABELS` environment variable to the `--node-labels` argument
- [20-extra-labels-infra.conf](src/20-extra-labels-infra.conf) - the drop-in that calls both scripts above and invokes the kubelet with the new mutated input arguments.
- [30-extra-labels.conf](src/30-extra-labels.conf) - the drop-in that defines `FIRST_BOOT_ONLY_KUBELET_NODE_EXTRA_LABELS` environment variable

## Injecting the drop-in
To leverage the drop-in during the first boot, it must be injected to the boot iso through the ignition configuration. This can be done a "developer way", or a "production way". Both ways involve creating the ignition and injecting it into the bootable iso the designated node will be installed from.

### The developer way
1. Incorporate the droop-in assets in the machine config files:
- [mc-kubelet-extra-labels.yaml](mc-kubelet-extra-labels.yaml) - contains the [extractExecStart](src/extractExecStart), [addExtraLabels](src/addExtraLabels) and [20-extra-labels-infra.conf](src/20-extra-labels-infra.conf) files.
- [mc-extra-labels.yaml](mc-extra-labels.yaml) - contains the[30-extra-labels.conf](src/30-extra-labels.conf) file.
The translation can be done using this infrastructure:
https://github.com/yuvalk/ocp-node-labels
2. Deploy the resulting machine configurations to your cluster and approve all pending `csr`. Make sure machine config server is serving the machine configurations for the machine  role of interest, for example using CURL. In the example below we check that `worker-rwn` ignition is served by the MCS:
```console
curl -L http://<cluster API IP or domain name>:22624/config/worker-rwn
```
3. Create the bootable ISO. This is easiest to do with [kcli](https://github.com/karmab/kcli):

```console
kcli create openshift-iso -P role=worker-rwn <cluster API IP or domain name>
```
Ther role must match the one served by the machine config server.
At this point `kcli` will download the RHCOS ISO, get the ignition from the machine config server and create the ISO for your node by embedding the downloaded ignition inside.

4. Spin a virtual worker. or install a physical one.
Virtual worker example with kcli:
```console
kcli create vm -P iso=cnfdt15.iso -P nets=["baremetal"] -P memory=8192 -P cpus=4 -P disks=[20] cnfdt15-worker4
```

### The production way
Will be explored upon transition to production, and will probably involve integration with https://github.com/openshift/assisted-service

## On the labeling scheme for PAO
Performance Addon operator is currently relying on the following labeling scheme:
```
<something>/<role>: ""
```
In this example we are using `node.kubernetes.io/worker-rwn=""`