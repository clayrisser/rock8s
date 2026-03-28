#!/bin/sh

_dns_provider_yaml() {
    case "$1" in
    cloudflare)
        _addon_yaml="$_addon_yaml
    cloudflare:
      email: ref+env://CLOUDFLARE_EMAIL
      api_key: ref+env://CLOUDFLARE_API_KEY"
        ;;
    route53)
        _addon_yaml="$_addon_yaml
    route53:
      access_key: ref+env://AWS_ACCESS_KEY_ID
      secret_key: ref+env://AWS_SECRET_ACCESS_KEY
      region: us-east-1"
        ;;
    hetzner)
        _addon_yaml="$_addon_yaml
    hetzner:
      api_key: ref+env://HETZNER_DNS_TOKEN"
        ;;
    digitalocean)
        _addon_yaml="$_addon_yaml
    digitalocean:
      api_token: ref+env://DIGITALOCEAN_TOKEN"
        ;;
    powerdns)
        _dns_url="$(_prompt "powerdns api_url" "")"
        _addon_yaml="$_addon_yaml
    powerdns:
      api_url: $_dns_url
      api_key: ref+env://PDNS_API_KEY"
        ;;
    *)
        fail "unsupported dns provider: $1"
        ;;
    esac
}

_cf="off"; _r53="off"; _hz="off"; _do="off"
case "$provider" in
hetzner) _hz="on" ;;
aws) _r53="on" ;;
digitalocean) _do="on" ;;
*) _cf="on" ;;
esac
_dns_selection=$(_dialog_checklist "Select DNS providers" \
    cloudflare "Cloudflare" "$_cf" \
    route53 "AWS Route53" "$_r53" \
    hetzner "Hetzner DNS" "$_hz" \
    digitalocean "DigitalOcean DNS" "$_do" \
    powerdns "PowerDNS" off)
for _dp in $_dns_selection; do
    _dns_provider_yaml "$_dp"
done
