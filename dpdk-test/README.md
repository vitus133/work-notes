# README #

This repository provides a set of manifests for verifying a basic dpdk functionality.The verification is done by:
- configuring a performance profile
- configuring SR-IOV
- defining two vfio-pci network attachments, exposing them to a pod and passing DPDK traffic between them using testpmd.

## What is this repository for? ##

Test like this was needed to verify that SR-IOV network operator can be configured to work without `Injector` and `OperatorWebhook` pods. The purpose of shutting down these two pods is just to reduce the number of running pods on Single Node Openshift clusters for far edge Telecom deployments.

## How do I get set up? ##
### Prerequisites ###
1. You need an Openshift cluster running on a bare metal host with SR-IOV capable NICs.
2. From the Openshift console install following operators:
    - Performance-Addon Operator
    - SR-IOV Network Operator
3. You need a container image with operational `testpmd` software. You can use the prebuilt one (quay.io/vgrinber/testpmd-container-app-testpmd:v0.2.2), or optionally build it yourself by initializing the `testpmd-container-app` git submodule and running `./build.sh testpmd` inside the submodule folder.

### Debug flow ###
1. Inspect the [performance.yaml](performance.yaml) and adapt it to your hardware (CPUs, hugepages) and cluster (node selector)
2. Apply the performance profile to your cluster 
   ```bash
   oc apply -f performance.yaml
   ```
   Wait for the node to finish reboots bu checking the node MCP has settled:
   ```bash
   $oc get mcp                                                                                                                                             
   NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   
   master   rendered-master-4a7263796b40dec7f9da32f36d38feb2   True      False      False      1              1                   1                     0                      
   ```
3. Check that you have SR-IOV capable NICs:
   ```bash
   oc get sriovnetworknodestates/<node name> -n openshift-sriov-network-operator -ojson
   ```
   Example output (partially omitted for brevity):
   ```json
    {
        "apiVersion": "sriovnetwork.openshift.io/v1",
        "kind": "SriovNetworkNodeState",
        "metadata": {
            "name": "cnfdt16.lab.eng.tlv2.redhat.com",
            "namespace": "openshift-sriov-network-operator",
        },
        "status": {
            "interfaces": [
                {
                    "deviceID": "158b",
                    "driver": "i40e",
                    "linkSpeed": "25000 Mb/s",
                    "linkType": "ETH",
                    "mac": "40:a6:b7:0d:9a:e1",
                    "mtu": 1500,
                    "name": "ens2f1",
                    "numVfs": 1,
                    "pciAddress": "0000:5e:00.1",
                    "totalvfs": 64,
                    "vendor": "8086"
                },
                {
                    "deviceID": "158b",
                    "driver": "i40e",
                    "linkSpeed": "25000 Mb/s",
                    "linkType": "ETH",
                    "mac": "40:a6:b7:0d:a5:e1",
                    "mtu": 1500,
                    "name": "ens7f1",
                    "numVfs": 1,
                    "pciAddress": "0000:86:00.1",
                    "totalvfs": 64,
                    "vendor": "8086"
                },
            ],
            "syncStatus": "Succeeded"
        }
    }

   ```
   The `status` shows NICs, two of which we are going to use to define virtual functions and later connect to our pod: ens2f1 and ens7f1
4. Inspect the [network-node-policy.yaml](network-node-policy.yaml) and adjust for your hardware and interface names
5. Apply the updated network-node-policy.yaml:
   ```bash
   oc apply -f network-node-policy.yaml
   ```
   Wait fir the node to finish rebooting. Check the virtual function have been created by issuing again
   ```bash
   oc get sriovnetworknodestates/<node name> -n openshift-sriov-network-operator -ojson
   ```
6. Apply the sriov-network.yaml:
   ```bash
   oc apply -f sriov-network.yaml
   ```
7. Create the pod on your cluster:
   ```bash
   oc apply -f pod.yaml
   ```
8. Get shell into the pod:
   ```bash
   oc project dpdk-net-ns
   oc rsh dpdk-base
   ```
9. Start `testpmd` in the interactive mode (output partially skipped for brevity):
    ```bash
    sh-4.4#  testpmd -l 0-7 -n 4 -- -i
    EAL: Detected 104 lcore(s)
    EAL: Detected 2 NUMA nodes
    EAL: Multi-process socket /var/run/dpdk/rte/mp_socket
    EAL: Selected IOVA mode 'VA'
    EAL: No available hugepages reported in hugepages-2048kB
    EAL: Probing VFIO support...
    EAL: VFIO support initialized
    EAL: PCI device 0000:5e:00.0 on NUMA socket 0
    EAL:   probe driver: 8086:158b net_i40e
    EAL: PCI device 0000:5e:00.1 on NUMA socket 0
    EAL:   probe driver: 8086:158b net_i40e
    EAL: PCI device 0000:5e:0a.0 on NUMA socket 0
    EAL:   probe driver: 8086:154c net_i40e_vf
    EAL:   using IOMMU type 1 (Type 1)
    EAL: PCI device 0000:86:00.0 on NUMA socket 1
    EAL:   probe driver: 8086:158b net_i40e
    EAL: PCI device 0000:86:00.1 on NUMA socket 1
    EAL:   probe driver: 8086:158b net_i40e
    EAL: PCI device 0000:86:0a.0 on NUMA socket 1
    EAL:   probe driver: 8086:154c net_i40e_vf
    EAL: PCI device 0000:af:00.0 on NUMA socket 1
    Interactive-mode selected
    testpmd: create a new mbuf pool <mbuf_pool_socket_0>: n=203456, size=2176, socket=0
    testpmd: preferred mempool ops selected: ring_mp_mc
    testpmd: create a new mbuf pool <mbuf_pool_socket_1>: n=203456, size=2176, socket=1
    testpmd: preferred mempool ops selected: ring_mp_mc
    Configuring Port 0 (socket 0)
    Port 0: 0A:25:F7:8D:BC:CF
    Configuring Port 1 (socket 1)
    Port 1: 62:E7:86:F7:8B:B4
    Checking link statuses...
    Done
    testpmd> 
    ```

    It can be seen that there are two ports exposed. We are going to send some traffic between them
10. Configure each port as a peer of the other port:
    ```bash
    testpmd> set eth-peer 0 62:E7:86:F7:8B:B4
    testpmd> set eth-peer 1 0A:25:F7:8D:BC:CF

    ```
11. Start traffic
    ```bash
    testpmd> start tx_first

    ```

12.  Stop traffic and check result:
        ```bash
        testpmd> stop
        Telling cores to stop...
        Waiting for lcores to finish...
        
        ---------------------- Forward statistics for port 0  ----------------------
        RX-packets: 150281860      RX-dropped: 0             RX-total: 150281860
        TX-packets: 150203072      TX-dropped: 0             TX-total: 150203072
        ----------------------------------------------------------------------------
        
        ---------------------- Forward statistics for port 1  ----------------------
        RX-packets: 150203072      RX-dropped: 0             RX-total: 150203072
        TX-packets: 150281860      TX-dropped: 0             TX-total: 150281860
        ----------------------------------------------------------------------------
        
        +++++++++++++++ Accumulated forward statistics for all ports+++++++++++++++
        RX-packets: 300484932      RX-dropped: 0             RX-total: 300484932
        TX-packets: 300484932      TX-dropped: 0             TX-total: 300484932
        ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        Done.
        
        ```
    
It can be seen that each port sends and receives data to / from another port
