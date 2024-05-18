# yams (you are my sunbeam)

> scripts to deploy microstack sunbeam

## Install

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -L || echo wget -O-) https://gitlab.com/bitspur/rock8s/yams/-/raw/main/scripts/single-nic.sh 2>/dev/null | sh
```

## Observe

```sh
watch snap list
```

```sh
watch --color -- juju status --color -m openstack
```

```sh
sudo watch microk8s.kubectl get all -A
```
