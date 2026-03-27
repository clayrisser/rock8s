# Ansible Conventions

## Task composition

- Use `import_tasks` (static, parse-time) — not `include_tasks` (dynamic)
- No Ansible tags anywhere — filter by **playbook** (`configure.yml` vs `publish.yml`) and **`when:`**

## Variable structure

All pfSense config lives under a single `pfsense:` dict in `vars.yml`:

```yaml
pfsense:
  system: ...
  network:
    interfaces:
      lan: ...
      wan: ...
  haproxy: ...
  firewall: ...
  dashboard: ...
```

HAProxy config is under `pfsense.haproxy` even though `haproxy` is a separate role.

## Task naming

- **Check tasks**: "Check current <area> configuration"
- **Configure tasks**: "Configure <area>"
- Imperative verb + noun: "Configure nat", "Configure routes"
- Avoid duplicate task names within a role (hurts log readability)

## Looping with zipped results

`dict2items` + `zip` for pairing items with their check results:

```yaml
loop: "{{ pfsense.network.interfaces | dict2items | zip(interface_check.results) | list }}"
```

Access as `item.0` (dict entry) and `item.1` (check result).

## Module usage

- `pfsensible.core` for supported surfaces (`pfsense_setup`, `pfsense_rule`)
- Embedded PHP via `ansible.builtin.shell` for everything else
- Collections vendored locally (`collections_paths = collections` in `ansible.cfg`)
- `gather_facts: false` on playbooks (pfSense appliance, not standard Linux)
