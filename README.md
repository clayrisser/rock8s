# rock8s 🚀🚀🚀

> a kubernetes cluster powered by Rancher, OLM and Kops

![](./rock8t.jpg)

**rock8s** stands for . . .

* R - Rancher
* O - Operator Lifecycle Manager
* C - Kops
* K8S - Kubernetes

**rock8s** is composed of the following projects

* **rock8s/cluster** - deployment scripts for a rock8s cluster
* **rock8s/charts** - rancher compatible helm charts optimized for the rock8s cluster
* **rock8s/patch-operator** - a custom operator for patching helm charts at deployment
* **rock8s/integration-operator** - a custom operator for integrations (inspired by juju charms)
* **rock8s/easy-olm-operator** - a custom operator that makes it easy to run OLM operator outside of OpenShift
* **rock8s/cli** - a custom cli for managing a rock8s cluster
