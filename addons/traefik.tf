data "kubernetes_service_v1" "traefik" {
  metadata {
    name      = "traefik"
    namespace = "kube-system"
  }
}
