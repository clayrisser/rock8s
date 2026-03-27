# References for OpenTofu Migration

## Similar Implementations

### Existing Hetzner provider

- **Location:** `providers/hetzner/`
- **Relevance:** This is the code being migrated — contains the `.tf` files, lock file, and shell glue
- **Key patterns:** `providers.tf` uses `terraform {}` block (stays same in OpenTofu), `tfvars.sh` reshapes JSON, `variables.sh` sources secrets

### OpenTofu migration docs

- **URL:** https://opentofu.org/docs/intro/migration
- **Relevance:** Confirms drop-in compatibility — same HCL syntax, same state format, registry auto-resolves to `registry.opentofu.org`
