#!/bin/sh

set -e

_resolve_single_ref() {
    ref="$1"
    scheme="${ref%%://*}"
    rest="${ref#*://}"
    path="${rest%%#*}"
    fragment=""
    case "$rest" in
        *"#"*) fragment="${rest#*#}" ;;
    esac
    value=""
    case "$scheme" in
        "ref+env")
            eval "value=\"\${$path:-}\""
            if [ -z "$value" ]; then
                fail "ref+env: environment variable not set: $path"
            fi
            ;;
        "ref+file")
            if [ ! -f "$path" ]; then
                fail "ref+file: file not found: $path"
            fi
            value="$(cat "$path")"
            ;;
        "ref+pass")
            command -v pass >/dev/null 2>&1 || fail "ref+pass: pass is not installed"
            value="$(pass show "$path")" || fail "ref+pass: failed to read: $path"
            ;;
        "ref+kms")
            command -v aws >/dev/null 2>&1 || fail "ref+kms: aws cli is not installed"
            value="$(printf '%s' "$path" | base64 -d | aws kms decrypt \
                --ciphertext-blob fileb:///dev/stdin \
                --output text --query Plaintext | base64 -d)" \
                || fail "ref+kms: failed to decrypt"
            ;;
        "ref+secretsmanager")
            command -v aws >/dev/null 2>&1 || fail "ref+secretsmanager: aws cli is not installed"
            value="$(aws secretsmanager get-secret-value \
                --secret-id "$path" \
                --query SecretString --output text)" \
                || fail "ref+secretsmanager: failed to read: $path"
            ;;
        "ref+ssm")
            command -v aws >/dev/null 2>&1 || fail "ref+ssm: aws cli is not installed"
            value="$(aws ssm get-parameter \
                --name "$path" \
                --with-decryption \
                --query Parameter.Value --output text)" \
                || fail "ref+ssm: failed to read: $path"
            ;;
        "ref+vault")
            command -v vault >/dev/null 2>&1 || fail "ref+vault: vault is not installed"
            if [ -n "$fragment" ]; then
                value="$(vault kv get -field="$fragment" "$path")" \
                    || fail "ref+vault: failed to read: $path#$fragment"
            else
                value="$(vault kv get -format=json "$path" | jq -r '.data.data // .data')" \
                    || fail "ref+vault: failed to read: $path"
            fi
            ;;
        "ref+gcsm")
            command -v gcloud >/dev/null 2>&1 || fail "ref+gcsm: gcloud is not installed"
            secret_name="${path%%/*}"
            secret_version="${path#*/}"
            if [ "$secret_version" = "$path" ]; then
                secret_version="latest"
            fi
            value="$(gcloud secrets versions access "$secret_version" \
                --secret="$secret_name")" \
                || fail "ref+gcsm: failed to read: $path"
            ;;
        "ref+azkeyvault")
            command -v az >/dev/null 2>&1 || fail "ref+azkeyvault: az is not installed"
            vault_name="${path%%/*}"
            secret_name="${path#*/}"
            value="$(az keyvault secret show \
                --vault-name "$vault_name" \
                --name "$secret_name" \
                --query value --output tsv)" \
                || fail "ref+azkeyvault: failed to read: $path"
            ;;
        *)
            fail "unsupported secret reference scheme: $scheme"
            ;;
    esac
    if [ -n "$fragment" ] && [ "$scheme" != "ref+vault" ]; then
        value="$(printf '%s' "$value" | jq -r ".$fragment // empty")" \
            || fail "failed to extract fragment '$fragment' from $ref"
        if [ -z "$value" ]; then
            fail "fragment '$fragment' not found in $ref"
        fi
    fi
    printf '%s' "$value"
}

resolve_refs() {
    input="$(cat)"
    has_refs="$(printf '%s' "$input" | jq -r '
        [paths(strings) as $p | getpath($p) | select(startswith("ref+"))] | length
    ')"
    if [ "$has_refs" = "0" ]; then
        printf '%s' "$input"
        return
    fi
    tmpfile="$(mktemp)"
    trap 'rm -f "$tmpfile"' EXIT
    printf '%s' "$input" | jq -r '
        paths(strings) as $p |
        select(getpath($p) | startswith("ref+")) |
        ($p | map(tostring) | join("\t")) + "\t" + getpath($p)
    ' > "$tmpfile"
    result="$input"
    while IFS="$(printf '\t')" read -r line; do
        ref_value="${line##*	}"
        path_parts="${line%	*}"
        resolved="$(_resolve_single_ref "$ref_value")"
        jq_path="$(printf '%s' "$path_parts" | awk -F'\t' '{
            out = ""
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+$/) {
                    out = out "[" $i "]"
                } else {
                    out = out ".\"" $i "\""
                }
            }
            print out
        }')"
        result="$(printf '%s' "$result" | jq --arg v "$resolved" "${jq_path} = \$v")"
    done < "$tmpfile"
    rm -f "$tmpfile"
    trap - EXIT
    printf '%s' "$result"
}
