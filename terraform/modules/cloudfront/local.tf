locals {
  fqdn = join(".", compact([var.source_subdomain, var.source_domain]))
  name = "redirect-${replace(local.fqdn, ".", "-")}"
}