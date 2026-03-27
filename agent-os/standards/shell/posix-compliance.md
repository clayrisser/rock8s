# POSIX Compliance

All shell scripts MUST be POSIX-compliant `/bin/sh`.

## Rules

- Shebang: `#!/bin/sh`
- No bashisms: no arrays (`arr=()`), no `[[ ]]`, no `read -a`, no `${var,,}`, no `<<<`
- Use `[ ]` not `[[ ]]` for tests
- Use `$(cmd)` not backticks
- Use `printf` over `echo` for portable output
- Parameter expansion only: `${var:-default}`, `${var#pattern}`, `${var%pattern}`
- Loops: `while ... do ... done`, `for x in ...; do ... done`
- No `local` keyword (not POSIX) — use `_` prefix convention instead

## Known violations to fix

- `lib/utils.sh` `parse_node_groups` uses `read -r -a` and `"${pairs[@]}"` — bash array syntax under `#!/bin/sh`

## Strict mode

Every script begins:

```sh
#!/bin/sh
set -e
```
