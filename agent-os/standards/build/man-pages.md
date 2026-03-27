# Man Page Generation

Man pages are auto-generated from `_help()` heredocs — do not edit `man/` directly.

## How it works

`manpages.sh` extracts `_help()` bodies via sed, then converts to roff:

1. Finds `_help()` function → extracts `cat <<EOF` … `EOF` block
2. Replaces section headers (`NAME`, `SYNOPSIS`, etc.) with `.SH NAME`, `.SH SYNOPSIS`
3. Rewrites `--help` cross-references to `man(1)` style
4. Outputs to `man/man1/rock8s-<group>-<cmd>.1`

## Requirements for _help()

- Must use `cat <<EOF >&2` format (sed mines this exact pattern)
- Must include man-page sections: `NAME`, `SYNOPSIS`, `DESCRIPTION`, `OPTIONS`
- Optional: `ARGUMENTS`, `COMMANDS`, `EXAMPLE`, `SEE ALSO`
- If extraction yields empty, a stub is generated

## Build

```sh
make manpages    # regenerates all man pages
make build       # depends on manpages
```

`man/` is gitignored — generated at build time.
