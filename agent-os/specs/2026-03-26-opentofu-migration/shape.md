# OpenTofu Migration — Shaping Notes

## Scope

Full cutover from Terraform to OpenTofu. Replace all `terraform` CLI invocations with `tofu`, regenerate lock file against OpenTofu registry, clean up legacy code, update docs.

## Decisions

- Full cutover — no backward compatibility, no `terraform` fallback
- `TF_VAR_*` and `TF_DATA_DIR` stay — OpenTofu reads these identically
- HCL `terraform {}` block stays — OpenTofu uses the same keyword
- Lock file regenerated — provider hashes from `registry.opentofu.org`
- Legacy `provider.terraform` migration code in `destroy.sh` removed
- File naming unchanged — `terraform.tfstate`, `terraform.tfvars.json`, `.terraform/` are standard in both

## Context

- **Visuals:** None
- **References:** Existing provider code in `providers/hetzner/`
- **Product alignment:** N/A (no product folder)

## Standards Applied

- shell/posix-compliance — all changes must stay POSIX sh
- shell/variable-naming — TF_VAR_* naming carries over
- providers/execution-model — tfvars.sh/variables.sh flow unchanged
- providers/purpose-based-infra — purpose dirs and init heuristics stay
- global/architecture — updated to reflect migration complete
