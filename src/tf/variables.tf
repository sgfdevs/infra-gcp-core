variable "gcp_organization_id" {
  description = "Numeric Google Cloud organization ID that owns the managed projects."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.gcp_organization_id))
    error_message = "Use the numeric organization ID without the organizations/ prefix."
  }
}

variable "gcp_billing_account_id" {
  description = "Billing account ID to link to the new project, not a credential."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}$", var.gcp_billing_account_id))
    error_message = "Use the billing account ID in XXXXXX-XXXXXX-XXXXXX format."
  }
}
