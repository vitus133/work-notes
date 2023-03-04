# README #

This repository provides a set of configurations for holding OCP boot until time synchronization is reached.
In a scenario of general power outage we can't rely on availability of NTP / PTP time sources when OCP boots. If in addition node RTC clock is out of order (e.g. backup battery died), booting the OCP without updating the time may lead to cluster certificates being invalid and cluster becoming unusable. Recovering such a cluster may require manual intervention (approving the CSRs).
This is a real case happenned to our partner.


### Prerequisites ###
1. `oc` CLI 
2. `butane` - utility for creating ignition / machineconfig files. Get it with 
```bash
curl https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane --output butane
```

### Usage ###
```bash
butane sync-clock.bu.yaml 
```