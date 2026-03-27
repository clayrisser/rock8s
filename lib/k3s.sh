#!/bin/sh

set -e

get_k3s_tls_sans() {
    if [ -n "$_K3S_TLS_SANS" ]; then
        echo "$_K3S_TLS_SANS"
        return
    fi
    entrypoint="$(get_entrypoint)"
    entrypoint_ipv4="$(get_entrypoint_ipv4)"
    master_private_ipv4s="$(get_master_private_ipv4s)"
    _K3S_TLS_SANS=""
    if [ -n "$entrypoint" ]; then
        _K3S_TLS_SANS="--tls-san $entrypoint"
    fi
    if [ -n "$entrypoint_ipv4" ]; then
        _K3S_TLS_SANS="$_K3S_TLS_SANS --tls-san $entrypoint_ipv4"
    fi
    for ipv4 in $master_private_ipv4s; do
        _K3S_TLS_SANS="$_K3S_TLS_SANS --tls-san $ipv4"
    done
    echo "$_K3S_TLS_SANS"
}

get_k3s_server_extra_args() {
    if [ -n "$_K3S_SERVER_EXTRA_ARGS" ]; then
        echo "$_K3S_SERVER_EXTRA_ARGS"
        return
    fi
    _K3S_SERVER_EXTRA_ARGS="--disable traefik --disable servicelb"
    tls_sans="$(get_k3s_tls_sans)"
    if [ -n "$tls_sans" ]; then
        _K3S_SERVER_EXTRA_ARGS="$_K3S_SERVER_EXTRA_ARGS $tls_sans"
    fi
    enable_dualstack="$(get_enable_network_dualstack)"
    if [ "$enable_dualstack" = "1" ]; then
        cluster_cidr="$(get_config '.k3s.cluster_cidr' '10.42.0.0/16,fd00:42::/56')"
        service_cidr="$(get_config '.k3s.service_cidr' '10.43.0.0/16,fd00:43::/112')"
        _K3S_SERVER_EXTRA_ARGS="$_K3S_SERVER_EXTRA_ARGS --cluster-cidr $cluster_cidr --service-cidr $service_cidr"
    fi
    k3s_extra="$(get_config '.k3s.extra_args' '')"
    if [ -n "$k3s_extra" ]; then
        _K3S_SERVER_EXTRA_ARGS="$_K3S_SERVER_EXTRA_ARGS $k3s_extra"
    fi
    echo "$_K3S_SERVER_EXTRA_ARGS"
}

get_k3s_first_master_ip() {
    if [ -n "$_K3S_FIRST_MASTER_IP" ]; then
        echo "$_K3S_FIRST_MASTER_IP"
        return
    fi
    _K3S_FIRST_MASTER_IP="$(get_master_private_ipv4s | head -1)"
    echo "$_K3S_FIRST_MASTER_IP"
}
