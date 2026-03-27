# Decouple pfSense from Cluster Lifecycle — Plan

## Scope

Separate pfSense into standalone shared infrastructure. Remove the `pfsense` purpose from cluster provisioning. Enforce LAN-only networking for all cluster nodes. Remove dead code paths for NAT toggles, public IPs, external network detection, and bastion login.

## Tasks

### Phase 1: pfSense state and CLI decoupling

1. Create pfSense state directory structure outside clusters: `$STATE_HOME/tenants/<tenant>/pfsense/<name>/`
2. Update `libexec/pfsense.sh` dispatcher — replace `--cluster` with `--name` (pfSense identity is independent of clusters)
3. Update `libexec/pfsense/apply.sh` — provision pfSense VMs using existing OpenTofu provider with `purpose=pfsense`, but store state under the new pfSense path
4. Update `libexec/pfsense/configure.sh` — reads pfSense config from its own state, not from a cluster's config.yaml
5. Update `libexec/pfsense/destroy.sh` — destroys from pfSense state path
6. Update `libexec/pfsense/publish.sh` — takes `--cluster` to know which cluster's HAProxy rules to push, but reads pfSense connection info from pfSense state

### Phase 2: Restore pfSense Ansible roles (PHP approach)

7. Restore `pfsense/` Ansible tree from git ref `d75ce15^` — roles/pfsense (dashboard, setup, system, interfaces, dhcp, sync, routes, nat, packages), roles/haproxy, roles/firewall, playbooks, vars.yml, requirements.yml
8. Discard OPNsense Ansible roles (current HEAD has OPNsense-specific code)
9. Verify `pfsensible.core` and `ansible.netcommon` dependencies in requirements.yml

### Phase 3: Remove pfsense purpose from cluster provisioning

10. Remove `pfsense` from purpose validation in `libexec/nodes/apply.sh` — valid purposes are `master` and `worker` only
11. Remove `pfsense` from purpose validation in `libexec/nodes/destroy.sh`
12. Remove pfsense dir dependency checks in `nodes/apply.sh` (lines 154-168) — master no longer requires `$CLUSTER_DIR/pfsense` to exist
13. Remove pfsense dir dependency checks in `nodes/destroy.sh` (lines 148-160)
14. Remove pfsense steps from `libexec/cluster/apply.sh` — no more `pfsense/apply.sh` call, no `--skip-pfsense`, no `--pfsense-password`, no `--pfsense-ssh-password`
15. Update `libexec/cluster/install.sh` — remove `--pfsense-password` / `--pfsense-ssh-password` flags; keep `pfsense/publish.sh` call but source pfSense connection info from config (not cluster state)
16. Update `libexec/cluster/upgrade.sh` — same as install.sh

### Phase 4: OpenTofu provider cleanup

17. Remove `purpose == "pfsense"` branches from `providers/hetzner/main.tf`:
    - Remove `hcloud_network.lan` resource (network creation) — master/worker always use `data.hcloud_network.lan`
    - Remove `hcloud_network_subnet.lan` resource
    - Remove `hcloud_network_route.default` resource
    - Remove `hcloud_network.sync` and `hcloud_network_subnet.sync` resources
    - Remove `var.pfsense_iso` from server resource
    - Simplify `firewall_ids` — no pfsense branch
    - Simplify `public_net` — always `ipv4_enabled = false`, `ipv6_enabled` from config
    - Simplify `network` block — always `data.hcloud_network.lan[0].id`
    - Remove dynamic `network` block for sync
18. Remove `pfsense` from purpose validation in `providers/hetzner/variables.tf`
19. Remove `variable "pfsense_iso"` from `providers/hetzner/variables.tf`
20. Remove all `pfsense_*` locals from `providers/hetzner/locals.tf` (lan IPs, sync IPs, sync network)
21. Remove `pfsense` branch from `providers/hetzner/tfvars.sh`
22. Simplify `providers/hetzner/variables.sh` — remove `purpose != "pfsense"` guard (cloud-init always runs), remove NAT conditional
23. Update `providers/hetzner/config.sh` — remove pfsense node type/hostname prompts from cluster config; add pfSense connection reference (hostname for publish step)

### Phase 5: LAN-only cleanup (remove dead code)

24. Remove `get_external_network()` from `libexec/lib/network.sh`
25. Remove `get_lan_ipv4_nat()` from `libexec/lib/network.sh`
26. Remove `get_lan_ingress_ipv4()` branching — always returns first MetalLB IP
27. Update `get_lan_metallb()` — remove `external_network` guard, MetalLB is always enabled
28. Update `libexec/cluster/addons.sh` — remove `get_external_network` call, `_LOAD_BALANCER_ENABLED` is always `"1"`
29. Remove `get_master_public_ipv4s()` from `libexec/lib/master.sh`
30. Remove `get_worker_public_ipv4s()` from `libexec/lib/worker.sh`
31. Remove `get_pfsense_public_ipv4s()` from `libexec/lib/pfsense.sh` (pfSense WAN IPs are managed by pfSense standalone, not cluster)
32. Update `libexec/lib/k3s.sh` `get_k3s_tls_sans()` — remove public IP SANs loop
33. Remove `bastion` argument from `libexec/cluster/login.sh` — always SSH to master private IP on LAN
34. Simplify `login.sh` kubeconfig rewrite — server URL is always master private IP

### Phase 6: lib/pfsense.sh refactor

35. Split `libexec/lib/pfsense.sh` into two concerns:
    - Helpers that derive pfSense info from cluster config (hostnames, LAN IPs from subnet) — stay in cluster lib, used by publish step
    - Helpers that read pfSense OpenTofu outputs (`get_pfsense_output_json`, `get_pfsense_ssh_private_key` from output.json) — move to pfSense standalone tool
36. Remove `get_pfsense_output_json_file()` / `get_pfsense_output_json()` dependency on `$CLUSTER_DIR/pfsense/` — pfSense state is at its own path
37. Update `get_pfsense_ssh_private_key()` — for cluster publish step, SSH key comes from config (not from cluster state output.json)

### Phase 7: Config schema update

38. Update cluster config.yaml schema — `pfsense:` section changes from node definitions (type, hostnames) to connection reference:
    ```yaml
    pfsense:
      hostname: pfsense1.example.com
      secondary_hostname: pfsense2.example.com  # optional, for HA
      ssh_private_key: /path/to/key             # optional, for publish step
    ```
39. Create pfSense standalone config — separate from cluster config, used by `rock8s pfsense` commands:
    ```yaml
    location: nbg1
    network:
      lan:
        mtu: 1450
        ipv4:
          subnet: 172.20.0.0/16
        ipv6:
          subnet: fd20::/64
      sync:
        ipv4:
          subnet: 172.21.0.0/16
    nodes:
      - type: cx22
        hostnames:
          - pfsense1.example.com
          - pfsense2.example.com
    ```

### Phase 8: Standards and docs

40. Update `agent-os/standards/providers/purpose-based-infra.md` — cluster purposes are master/worker only
41. Update `agent-os/standards/global/architecture.md` — pfSense is standalone shared infrastructure, LAN-only model
42. Update `libexec/completion.sh` — remove pfsense from node purposes, update pfsense subcommand completions
43. Update `libexec/nodes/ls.sh`, `libexec/nodes/ssh.sh`, `libexec/nodes/pubkey.sh` — remove pfsense as a node purpose
