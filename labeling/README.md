# Node auto-labelling

When OCP worker node is created, it automatically joins the `worker` mavhine config pool. If we want it to be in a custom pool, we must label the node. The machine config operator will then detect the change and join the node to the pool, which will lead to reboot.
If we want to eliminate this reboot, an option could be to add the label to the kubelet command line options, but MCO does not provide an API for that. If we change the kubelet.service MCO will detect the change and annotate the node as degraded.

But we can work around this feature / limitation using systemd dropin mechanism, that allows mutating the service.

Here we overlay the kubelet.service and add a label using this technique.