#!/bin/bash

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s completion

SYNOPSIS
       rock8s completion [bash|zsh]

DESCRIPTION
       Generate shell completion scripts for rock8s

       Without arguments, it will detect your current shell and print the appropriate completion script.

       For bash, use: source <(rock8s completion bash)
       For zsh, use: source <(rock8s completion zsh)

       For permanent setup, add the source command to your ~/.bashrc or ~/.zshrc file.
EOF
}

_bash_completion() {
    cat <<'EOF'
_rock8s_completion() {
    local cur prev words cword
    if type -t _get_comp_words_by_ref >/dev/null 2>&1; then
        _get_comp_words_by_ref -n = cur prev words cword
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword="${COMP_CWORD}"
    fi
    local commands="nodes cluster pfsense completion"
    local global_opts="-h --help -d --debug -o --output -t --tenant -c --cluster"
    local nodes_cmds="ls create destroy ssh"
    local cluster_cmds="configure setup bootstrap"
    local pfsense_cmds="configure list"
    local completion_cmds="bash zsh"
    local node_types="master worker"
    if [[ ${cword} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${commands} ${global_opts}" -- "${cur}"))
        return 0
    fi
    if [[ ${prev} == "-o" || ${prev} == "--output" ]]; then
        COMPREPLY=($(compgen -W "json yaml text" -- "${cur}"))
        return 0
    elif [[ ${prev} == "-t" || ${prev} == "--tenant" ]]; then
        if [ -d "${XDG_STATE_HOME:-$HOME/.local/state}/rock8s/tenants" ]; then
            local tenants=$(find "${XDG_STATE_HOME:-$HOME/.local/state}/rock8s/tenants" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null || echo "")
            COMPREPLY=($(compgen -W "${tenants}" -- "${cur}"))
        fi
        return 0
    elif [[ ${prev} == "-c" || ${prev} == "--cluster" ]]; then
        if [ -d "${XDG_STATE_HOME:-$HOME/.local/state}/rock8s/clusters" ]; then
            local clusters=$(find "${XDG_STATE_HOME:-$HOME/.local/state}/rock8s/clusters" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null || echo "")
            COMPREPLY=($(compgen -W "${clusters}" -- "${cur}"))
        fi
        return 0
    fi
    if [[ ${cword} -gt 1 ]]; then
        local cmd="${words[1]}"
        case "${cmd}" in
            nodes)
                if [[ ${cword} -eq 2 ]]; then
                    COMPREPLY=($(compgen -W "${nodes_cmds}" -- "${cur}"))
                elif [[ ${cword} -eq 3 && ${words[2]} == "ssh" ]]; then
                    COMPREPLY=($(compgen -W "${node_types}" -- "${cur}"))
                elif [[ ${cword} -eq 4 && ${words[2]} == "ssh" ]]; then
                    local node_numbers="1 2 3"
                    local cluster=""
                    for ((i=1; i<cword; i++)); do
                        if [[ "${words[i]}" == "-c" || "${words[i]}" == "--cluster" ]]; then
                            cluster="${words[i+1]}"
                            break
                        fi
                    done
                    if [[ -n "$cluster" && -d "${XDG_STATE_HOME:-$HOME/.local/state}/rock8s/clusters/$cluster" ]]; then
                        :
                    fi
                    COMPREPLY=($(compgen -W "${node_numbers}" -- "${cur}"))
                fi
                ;;
            cluster)
                if [[ ${cword} -eq 2 ]]; then
                    COMPREPLY=($(compgen -W "${cluster_cmds}" -- "${cur}"))
                fi
                ;;
            pfsense)
                if [[ ${cword} -eq 2 ]]; then
                    COMPREPLY=($(compgen -W "${pfsense_cmds}" -- "${cur}"))
                fi
                ;;
            completion)
                if [[ ${cword} -eq 2 ]]; then
                    COMPREPLY=($(compgen -W "${completion_cmds}" -- "${cur}"))
                fi
                ;;
        esac
        return 0
    fi
    return 0
}
complete -F _rock8s_completion rock8s
EOF
}

_zsh_completion() {
    cat <<'EOF'
#compdef rock8s
(( $+functions[compinit] )) || autoload -Uz compinit && compinit
_rock8s() {
    local line state
    local -a node_types
    node_types=(
        'master:Master node'
        'worker:Worker node'
    )
    _arguments -C \
        '-h[Show help message]' \
        '--help[Show help message]' \
        '-d[Debug mode]' \
        '--debug[Debug mode]' \
        '-o[Output format]:format:(json yaml text)' \
        '--output=[Output format]:format:(json yaml text)' \
        '-t[Tenant name]:tenant:->tenants' \
        '--tenant=[Tenant name]:tenant:->tenants' \
        '-c[Cluster name]:cluster:->clusters' \
        '--cluster=[Cluster name]:cluster:->clusters' \
        '1: :->cmds' \
        '*::arg:->args'
    case $state in
        tenants)
            local tenants_dir="${XDG_STATE_HOME:-$HOME/.local/state}/rock8s/tenants"
            if [[ -d "$tenants_dir" ]]; then
                local tenant_list
                tenant_list=( ${(f)"$(find "$tenants_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null || echo "")"} )
                _values 'tenants' $tenant_list
            fi
            ;;
        clusters)
            local clusters_dir="${XDG_STATE_HOME:-$HOME/.local/state}/rock8s/clusters"
            if [[ -d "$clusters_dir" ]]; then
                local cluster_list
                cluster_list=( ${(f)"$(find "$clusters_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null || echo "")"} )
                _values 'clusters' $cluster_list
            fi
            ;;
        cmds)
            _values 'rock8s command' \
                'nodes[Create and manage cluster nodes]' \
                'cluster[Create kubernetes clusters]' \
                'pfsense[Configure and manage pfsense firewall]' \
                'completion[Generate shell completion scripts]'
            ;;
        args)
            case $line[1] in
                nodes)
                    if (( CURRENT == 2 )); then
                        _values 'nodes subcommand' \
                            'ls[List nodes]' \
                            'create[Create nodes]' \
                            'destroy[Destroy nodes]' \
                            'ssh[SSH into a node]'
                    elif (( CURRENT == 3 )) && [[ $line[2] == "ssh" ]]; then
                        _describe -t node_types "node type" node_types
                    elif (( CURRENT == 4 )) && [[ $line[2] == "ssh" ]]; then
                        local cluster=""
                        local -a words=( ${line} )
                        for ((i=1; i<$#words; i++)); do
                            if [[ "${words[i]}" == "-c" || "${words[i]}" == "--cluster" ]]; then
                                cluster="${words[i+1]}"
                                break
                            fi
                        done
                        _values 'node number' 1 2 3
                    fi
                    ;;
                cluster)
                    _values 'cluster subcommand' \
                        'configure[Configure a cluster]' \
                        'setup[Set up a cluster]' \
                        'bootstrap[Bootstrap a cluster]'
                    ;;
                pfsense)
                    _values 'pfsense subcommand' \
                        'configure[Configure pfsense]' \
                        'list[List pfsense configurations]'
                    ;;
                completion)
                    _values 'completion subcommand' 'bash' 'zsh'
                    ;;
            esac
            ;;
    esac
}
_rock8s
EOF
}

_main() {
    if [ $# -eq 0 ]; then
        case "$SHELL" in
            */zsh)
                _zsh_completion
                ;;
            */bash)
                _bash_completion
                ;;
            *)
                echo "rock8s completion [bash|zsh]" >&2
                exit 1
                ;;
        esac
    else
        case "$1" in
            bash)
                _bash_completion
                ;;
            zsh)
                _zsh_completion
                ;;
            -h|--help)
                _help
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    fi
}

_main "$@"
