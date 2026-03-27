# HA Primary/Secondary

A boolean `primary` variable controls which pfSense node is active for stateful services.

## What `primary` controls

| Area | Primary | Secondary |
|------|---------|-----------|
| NAT rules | Applied (`when: primary`) | Skipped |
| HAProxy settings | Applied | Skipped |
| CARP skew | `advskew: 0` | `advskew: 100` |
| Interface IPs | `item.value.ipv4.primary` | `item.value.ipv4.secondary` |
| Hostname | `primary` | `secondary` |
| Dashboard theme | `pfsense.dashboard.primary.*` | `pfsense.dashboard.secondary.*` |

## How it's supplied

`primary` is **not** in `vars.yml` — it must come from inventory or `-e` on the command line.

## IP selection pattern

```yaml
"{{ primary | ternary(item.value.ipv4.primary, item.value.ipv4.secondary | default(item.value.ipv4.primary)) }}"
```

Secondary falls back to primary if not defined.

## Playbook split

- `configure.yml` — full configure: `pfsense` + `firewall` + `haproxy` roles
- `publish.yml` — sync-only: `firewall` + `haproxy` roles (skips core pfSense config)
