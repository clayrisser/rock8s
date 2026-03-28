data "http" "olm_crds" {
  count = var.enabled ? 1 : 0
  url   = "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${var.olm_version}/crds.yaml"
}

data "http" "olm_manifests" {
  count = var.enabled ? 1 : 0
  url   = "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${var.olm_version}/olm.yaml"
}

data "kubectl_file_documents" "olm_crds" {
  count   = var.enabled ? 1 : 0
  content = data.http.olm_crds[0].response_body
}

data "kubectl_file_documents" "olm_manifests" {
  count   = var.enabled ? 1 : 0
  content = data.http.olm_manifests[0].response_body
}

resource "kubectl_manifest" "olm_crds" {
  for_each          = var.enabled ? data.kubectl_file_documents.olm_crds[0].manifests : {}
  yaml_body         = each.value
  server_side_apply = true
  lifecycle {
    ignore_changes = [yaml_body]
  }
}

resource "kubectl_manifest" "olm_manifests" {
  for_each          = var.enabled ? data.kubectl_file_documents.olm_manifests[0].manifests : {}
  yaml_body         = each.value
  force_conflicts   = true
  server_side_apply = true
  lifecycle {
    ignore_changes = [yaml_body]
  }
  depends_on = [kubectl_manifest.olm_crds]
}
