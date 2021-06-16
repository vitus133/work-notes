# Site config operator scaffold with Ansible
We can convert site definitions to assisted installer CRs using this operator scaffold created using operator-sdk.
It allows creating Site CRD
[config/crd/bases/ran.openshift.io_sites.yaml]([config/crd/bases/ran.openshift.io_sites.yaml) and adding a custom controller that will run Ansible role or playbook when a site CR changes.
For example, if I add a site CR like this
```yml
apiVersion: ran.openshift.io/v1alpha1
kind: Site
metadata:
  name: sample-site
  namespace: tutorial
spec:
  message: foo
  agent:
    label: du-sno888
```
and I have a play like this
```yml
# tasks file for Site
- name: Check we can access CR spec
  debug:
    msg: "message value from CR spec: {{ message }}"

- name: Check we can access CR spec
  debug:
    msg: "Agent label value from CR spec: {{ agent.label }}"

```

then I have log like this:

```console
oc -n ran-operator-system logs pod/ran-operator-controller-manager-6bf49b46c7-4rw9w -c manager -f
{"level":"info","ts":1623843845.193556,"logger":"cmd","msg":"Version","Go Version":"go1.16.5","GOOS":"linux","GOARCH":"amd64","ansible-operator":"v1.8.0","commit":"d3bd87c6900f70b7df618340e1d63329c7cd651e"}
{"level":"info","ts":1623843845.193919,"logger":"cmd","msg":"Watch namespaces not configured by environment variable WATCH_NAMESPACE or file. Watching all namespaces.","Namespace":""}
I0616 11:44:06.247152       7 request.go:655] Throttling request took 1.019417298s, request: GET:https://10.217.4.1:443/apis/k8s.cni.cncf.io/v1?timeout=32s
{"level":"info","ts":1623843847.8587298,"logger":"controller-runtime.metrics","msg":"metrics server is starting to listen","addr":"127.0.0.1:8080"}
{"level":"info","ts":1623843847.8600492,"logger":"watches","msg":"Environment variable not set; using default value","envVar":"ANSIBLE_VERBOSITY_SITE_RAN_OPENSHIFT_IO","default":2}
{"level":"info","ts":1623843847.8602252,"logger":"cmd","msg":"Environment variable not set; using default value","Namespace":"","envVar":"ANSIBLE_DEBUG_LOGS","ANSIBLE_DEBUG_LOGS":false}
{"level":"info","ts":1623843847.8602586,"logger":"ansible-controller","msg":"Watching resource","Options.Group":"ran.openshift.io","Options.Version":"v1alpha1","Options.Kind":"Site"}
{"level":"info","ts":1623843847.86164,"logger":"proxy","msg":"Starting to serve","Address":"127.0.0.1:8888"}
I0616 11:44:07.861923       7 leaderelection.go:243] attempting to acquire leader lease ran-operator-system/ran-operator...
{"level":"info","ts":1623843847.8619878,"logger":"controller-runtime.manager","msg":"starting metrics server","path":"/metrics"}
I0616 11:44:07.873843       7 leaderelection.go:253] successfully acquired lease ran-operator-system/ran-operator
{"level":"info","ts":1623843847.8741848,"logger":"controller-runtime.manager.controller.site-controller","msg":"Starting EventSource","source":"kind source: ran.openshift.io/v1alpha1, Kind=Site"}
{"level":"info","ts":1623843847.9758437,"logger":"controller-runtime.manager.controller.site-controller","msg":"Starting Controller"}
{"level":"info","ts":1623843847.9759045,"logger":"controller-runtime.manager.controller.site-controller","msg":"Starting workers","worker count":4}

--------------------------- Ansible Task StdOut -------------------------------

 TASK [Check we can access CR spec] ******************************** 
ok: [localhost] => {
    "msg": "message value from CR spec: foo"
}

-------------------------------------------------------------------------------
{"level":"info","ts":1623843873.399265,"logger":"logging_event_handler","msg":"[playbook debug]","name":"sample-site","namespace":"tutorial","gvk":"ran.openshift.io/v1alpha1, Kind=Site","event_type":"runner_on_ok","job":"4037200794235010051","EventData.TaskArgs":""}
{"level":"info","ts":1623843873.5543299,"logger":"logging_event_handler","msg":"[playbook debug]","name":"sample-site","namespace":"tutorial","gvk":"ran.openshift.io/v1alpha1, Kind=Site","event_type":"runner_on_ok","job":"4037200794235010051","EventData.TaskArgs":""}

--------------------------- Ansible Task StdOut -------------------------------

 TASK [Check we can access CR spec] ******************************** 
ok: [localhost] => {
    "msg": "Agent label value from CR spec: du-sno888"
}

-------------------------------------------------------------------------------
{"level":"info","ts":1623843873.908855,"logger":"runner","msg":"Ansible-runner exited successfully","job":"4037200794235010051","name":"sample-site","namespace":"tutorial"}

----- Ansible Task Status Event StdOut (ran.openshift.io/v1alpha1, Kind=Site, sample-site/tutorial) -----


PLAY RECAP *********************************************************************
localhost                  : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


----------

```

I can easily create k8s resources with Ansible k8s module.

The operator framework does all the hard work for me.

## Usage
1. Edit hte Makefile to point to your quay.io or dockerhub account in `deploy` and `docker-push` targets
1. Run 
    ```bash
    make docker-build docker-push deploy

    ```
All set