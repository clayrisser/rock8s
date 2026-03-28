module "flux" {
  source  = "./modules/flux"
  enabled = var.flux != null

  capacitor_next_enabled       = var.flux != null && try(var.flux.capacitor_next.enabled, true)
  capacitor_next_chart_version = try(var.flux.capacitor_next.chart_version, "0.14.0")
  capacitor_next_values        = try(var.flux.capacitor_next.values, "")
}
