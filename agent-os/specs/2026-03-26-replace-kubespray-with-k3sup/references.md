# References for Replace Kubespray with k3sup

## Similar Implementations

### Current Kubespray integration

- **Location:** `libexec/cluster/install.sh`, `libexec/cluster/upgrade.sh`, `libexec/cluster/scale.sh`, `libexec/cluster/reset.sh`, `libexec/cluster/node/rm.sh`, `libexec/lib/kubespray.sh`, `kubespray/vars.yml`, `kubespray/postinstall.yml`
- **Relevance:** This is what we're replacing. Understanding the current flow is essential.
- **Key patterns:** Shell scripts orchestrate Ansible playbooks via SSH keys and IPs from OpenTofu outputs.

### OpenTofu migration spec

- **Location:** `agent-os/specs/2026-03-26-opentofu-migration/`
- **Relevance:** The Terraform → OpenTofu migration is a related modernization effort. The k3sup migration should align with OpenTofu conventions (using `tofu` not `terraform`).

## External References

- **k3sup**: https://github.com/alexellis/k3sup (7.2k stars, MIT, Go binary)
- **k3s-ansible**: https://github.com/k3s-io/k3s-ansible (2.7k stars, considered but not chosen)
- **Striveworks k3s provider**: https://github.com/Striveworks/terraform-provider-k3s (5 stars, considered but too immature)
- **marshallford/pfsense provider**: https://github.com/marshallford/terraform-provider-pfsense (not ready to replace Ansible for pfSense)
