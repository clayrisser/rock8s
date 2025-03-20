module "kyverno" {
  source  = "./modules/kyverno"
  enabled = var.kyverno != null
  values  = <<EOF
backgroundController:
  rbac:
    clusterRole:
      extraResources:
        - apiGroups:
            - ''
          resources:
            - configmaps
            - secrets
            - serviceaccounts
          verbs:
            - '*'
        - apiGroups:
            - apps
          resources:
            - deployments
            - daemonsets
            - replicasets
            - statefulsets
          verbs:
            - '*'
        - apiGroups:
            - cr.kanister.io
          resources:
            - blueprints
          verbs:
            - '*'
        - apiGroups:
            - k8s.keycloak.org
          resources:
            - keycloaks
            - keycloakrealmimports
          verbs:
            - '*'
        - apiGroups:
            - helm.toolkit.fluxcd.io
          resources:
            - helmreleases
          verbs:
            - '*'
        - apiGroups:
            - temporal.io
          resources:
            - temporalclusters
          verbs:
            - '*'
        - apiGroups:
            - ''
          resources:
            - pods
          verbs:
            - '*'
EOF
}
