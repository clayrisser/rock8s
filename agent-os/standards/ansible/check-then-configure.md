# Check-Then-Configure Idempotency

pfSense tasks follow a two-phase pattern: check current state, then update only if changed.

## Pattern

1. **Check task** — shell script writes PHP that compares `$current` vs `$desired`, outputs JSON `{"changed": true/false}`
2. **Register** result, use `changed_when: (result.stdout | from_json).changed`
3. **Configure task** — runs only when check reports changed (`when: check_result is changed`)

```yaml
- name: Check current interface configuration
  ansible.builtin.shell: |
    php -r '
    require_once("config.inc");
    parse_config(true);
    $current = ...;
    $desired = ...;
    echo json_encode(["changed" => $current !== $desired]);
    '
  register: interface_check
  changed_when: (interface_check.stdout | from_json).changed

- name: Configure interfaces
  ansible.builtin.shell: |
    php -r '...'
  when: interface_check is changed
```

## Normalization

Always normalize before comparing to prevent flapping:
- `normalize_bool`: coerce empty string / true / false
- `normalize_config`: recursive — `null` → `''`, bools → string equivalents
- `normalize_rule`: for NAT rules

## Why embedded PHP

`pfsensible.core` modules cover limited surfaces. For interfaces, NAT, routes, DHCP, and system config, direct PHP with `config.inc` / `write_config()` / `filter_configure()` is required.

## Commit messages

Always include ansible user and host:

```php
sprintf('Updated ... from ansible (%s@%s)', '{{ ansible_user }}', '{{ ansible_host }}')
```
