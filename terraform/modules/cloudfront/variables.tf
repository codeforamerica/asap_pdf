variable "create_records" {
  type        = bool
  description = "Create DNS records using Route 53. A hosted zone matching the source domain must exist. If false, the certificate must be manually validated."
  default     = true
}

variable "destination" {
  type        = string
  description = "Destination for redirects, including scheme (e.g. https://my.domain.com)."
}

variable "logging_bucket" {
  description = "The S3 bucket used for logging."
  type        = string
}

variable "static" {
  type        = bool
  description = "Redirect to the destination without passing the path."
  default     = false
}

variable "status_code" {
  type        = number
  description = "HTTP status code for the redirect."
  default     = 301

  validation {
    condition     = var.status_code == 301 || var.status_code == 302
    error_message = "Status code must be either 301 or 302."
  }
}

variable "source_domain" {
  type        = string
  description = "Domain to redirect from. This should match the hosted zone when creating verification records."
}

variable "source_subdomain" {
  type        = string
  description = "Optional subdomain for the source redirect. Required if the fully qualified domain name (FQDN) is a subdomain of the hosted zone domain."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}