# Firewall Rules DSL

Firewall rules use a natural-language mini-DSL parsed by Jinja into `pfsensible.core.pfsense_rule` args.

## Syntax

```
<action> from <source> to <destination> [<protocol>] [port <port>]
```

Examples:

```yaml
pfsense:
  firewall:
    rules:
      - allow from self to any
      - allow from self to any tcp port 443
      - allow from any to self udp port 53
      - block from any to any
```

## Service name map

Named ports resolve via a built-in map:

```yaml
service_ports:
  dns: 53
  http: 80
  https: 443
  ...
```

## IPv4 vs IPv6 split

- **IPv4** (no `:` or `[` in rule): uses `pfsensible.core.pfsense_rule` module
- **IPv6** (contains `:` or `[`): uses embedded PHP (module doesn't support IPv6)

## Source/destination keywords

- `self` → the interface key (e.g. `lan`, `wan`)
- `any` → any address
- Specific IPs/CIDRs used directly

## WAN exclusion

Interface-level rules loop with `when: item.key != 'wan'` — WAN gets separate treatment.
