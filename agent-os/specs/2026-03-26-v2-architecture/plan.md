# rock8s v2 Architecture — Plan

Clean break from v1. Config file is the single source of truth, checked into git. Secrets resolved at runtime via `ref+` references. No interactive prompts. Remote state support. No backward compatibility.

## Phases

1. Config-first / remove prompts
2. Secret reference resolution (`ref+provider://...`)
3. Remote state backend support
4. Existing pfSense support
5. k3s migration (replacing kubespray)
6. Multi-arch node support
7. pfSense image arch parameterization
