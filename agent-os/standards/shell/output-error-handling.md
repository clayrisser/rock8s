# Output & Error Handling

## Primitives (from `lib/utils.sh`)

| Function | Behavior |
|----------|----------|
| `fail "msg"` | `error` + `exit 1` |
| `error "msg"` | JSON `{"error":"msg"}` through `format_output` |
| `warn "msg"` | stderr, no exit |
| `log "msg"` | stderr, informational |
| `debug "msg"` | stderr, only when `ROCK8S_DEBUG=1` |
| `success "msg"` | JSON structured output through `format_output` |

## Output formats

`-o` / `--output` flag or `ROCK8S_OUTPUT` env: `text` (default), `json`, `yaml`

All structured output passes through `format_output <format> <type>`:

```sh
printf '%s\n' "$_JSON" | format_output "$_OUTPUT" nodes
```

## JSON tables (text mode)

`format_json_table` renders JSON arrays as aligned columns:
- Uses `⋮` (vertical ellipsis) as column delimiter
- Headers uppercased via `tr`
- Lines truncated to terminal width (`tput cols`)

## Error output

- Errors always go to stderr
- JSON mode: `{"error": "..."}`
- Text mode: red-colored message

## Retry helper

```sh
try <command>    # uses $RETRIES
```

Retries with 1s sleep, traps INT → exit 130.
