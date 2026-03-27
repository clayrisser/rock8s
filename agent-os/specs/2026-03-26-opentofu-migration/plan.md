# OpenTofu Migration — Plan

## Scope

Replace Terraform with OpenTofu across the entire codebase. Drop-in CLI swap (`terraform` to `tofu`), use the OpenTofu registry for providers, no backward compatibility. The CLI dispatch pattern, variable flow (`tfvars.sh`, `variables.sh`, `TF_VAR_*`), and purpose-based infra model all stay unchanged.

## Tasks

1. Save spec documentation (this folder)
2. Update `ensure_system` in `libexec/lib/utils.sh`: `terraform` to `tofu`
3. Replace `terraform` with `tofu` in `libexec/nodes/apply.sh` (3 calls)
4. Replace `terraform` with `tofu` in `libexec/nodes/destroy.sh` (2 calls), remove `provider.terraform` legacy migration
5. Replace `terraform` with `tofu` in `libexec/cluster/addons.sh` (3 calls)
6. Delete `providers/hetzner/.terraform.lock.hcl` and regenerate with `tofu init`
7. Update `.gitignore` comment and add `.tofurc`/`tofu.rc` patterns
8. Add `opentofu` and `tofu` to `project-words.txt`
9. Update standards files and `index.yml` to reflect OpenTofu as current
10. Verify no stale `terraform` CLI references remain in shell scripts
