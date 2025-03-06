resource "kubectl_manifest" "namespace" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.namespace}
EOF
}

resource "kubernetes_config_map" "init" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "init"
    namespace = var.namespace
  }
  data = {
    "init.sh" = <<EOF
#!/bin/sh
while true; do
  vault status 
  [[ $? -eq 1 ]] || break
done
vault operator init -key-shares=3 > /home/vault/init-tmp
if [ $? -eq 0 ]; then
  mv /home/vault/init-tmp /vault/data/seal-keys
else
  rm /home/vault/init-tmp
fi
for i in 1 2 3; do
  vault operator unseal $(grep "Key $i" /vault/data/seal-keys |sed 's/Unseal Key '$i': //i') 
done
vault login "$(grep 'Initial Root Token:' /vault/data/seal-keys | cut -d' ' -f4)"
vault auth enable kubernetes
K8S_HOST="https://$(env | grep KUBERNETES_PORT_443_TCP_ADDR| cut -f2 -d'='):443"
SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
SA_CERT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
vault write auth/kubernetes/config \
    token_reviewer_jwt="$SA_TOKEN" \
    kubernetes_host="$K8S_HOST" \
    kubernetes_ca_cert="@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
vault write auth/kubernetes/role/argocd \
  bound_service_account_names=argocd-repo-server \
  bound_service_account_namespaces=argocd \
  policies=argocd \
  ttl=48h
EOF
  }
  depends_on = [
    kubectl_manifest.namespace
  ]
}

resource "helm_release" "vault" {
  count      = var.enabled ? 1 : 0
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  name       = "vault"
  namespace  = var.namespace
  values = [<<EOF
  server:
    dataStorage:
      enabled: true
    auditStorage:
      enabled: true
    standalone:
      enabled: true
    ha:
      enabled: false
    readinessProbe:
      enabled: false
    postStart:
      - sh
      - /vault/userconfig/init/init.sh
    extraVolumes:
      - type: configMap
        name: init
        path: /vault/userconfig
  ui:
    enabled: true
EOF
    ,
  var.values]
  depends_on = [
    kubernetes_config_map.init
  ]
}
