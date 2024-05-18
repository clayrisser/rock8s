# yams (you are my sunbeam)

> scripts to deploy sunbeam microstack

While sunbeam microstack does a great job at deploying openstack, it still
expects certain prerequisites to be configured, such as the networking.

These scripts prepare the requirements and then proceed to install openstack
with sunbeam microstack.

## Install

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -L || echo wget -O-) https://gitlab.com/bitspur/rock8s/yams/-/raw/main/scripts/single-nic.sh 2>/dev/null | sh
```

## Observe

_To observe progress, run each command in a new session_

```sh
watch snap list
```

```sh
watch --color -- juju status --color -m openstack
```

```sh
sudo watch microk8s.kubectl get all -A
```
