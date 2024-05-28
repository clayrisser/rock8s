# yams

> scripts to deploy openstack

## Install

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -L || echo wget -O-) https://gitlab.com/bitspur/rock8s/yams/-/raw/main/scripts/prepare.sh 2>/dev/null | sh
```

## Reference

This reference makes the following assumptions

- base domain is `example.com`
- region is `eu0`
- 3 servers with the following public ips
  - `142.251.33.101`
  - `17.253.144.10`
  - `93.184.215.14`

### DNS Records

| DNS Name                                     | IP Address                                       |
| -------------------------------------------- | ------------------------------------------------ |
| `api-eu0.example.com`                        | `142.251.33.101` `17.253.144.10` `93.184.215.14` |
| `cloud.example.com`                          | `142.251.33.101` `17.253.144.10` `93.184.215.14` |
| `portal.example.com`                         | `142.251.33.101` `17.253.144.10` `93.184.215.14` |
| `s3-eu0.example.com`                         | `142.251.33.101` `17.253.144.10` `93.184.215.14` |
| `ctl0-eu0.example.com` `ns1-eu0.example.com` | `142.251.33.101`                                 |
| `ctl1-eu0.example.com` `ns2-eu0.example.com` | `17.253.144.10`                                  |
| `ctl2-eu0.example.com` `ns3-eu0.example.com` | `93.184.215.14`                                  |

### Switch VLANs

| Name       | ID     |
| ---------- | ------ |
| `provider` | `4000` |
| `mgmt`     | `4001` |
| `lb-mgmt`  | `4002` |
