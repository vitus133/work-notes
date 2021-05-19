# Node auto-labelling

When OCP worker node is created, it automatically joins the `worker` machine config pool. If we want it to be in a custom pool, we must label the node. The machine config operator will then detect the change and join the node to the pool, which will lead to reboot.
If we want to eliminate this reboot, an option could be to add the label to the kubelet command line options, but MCO does not provide an API for that. If we change the kubelet.service MCO will detect the change and annotate the node as degraded.

We can work around this feature / limitation using `systemd` dropin mechanism, that allows mutating the systemd unit.

Here we overlay the kubelet.service and add a label using this technique.

## Procedure
1. The [mc-rwn.yaml](mc-rwn.yaml) provides the dropin to the kubelet systemd unit and an auxiliary script for extending kubelet command line arguments with additional label(s).
2. This manifest must be compiled into the cluster ignition file
3. The cluster ignition file extended with our custom manifest is used to create the RHCOS iso file used to install workers intended for our custom machine config pool. When installed, the nodes will be automatically labeled with our custom label on the first boot after the install
