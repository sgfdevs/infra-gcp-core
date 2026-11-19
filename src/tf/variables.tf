variable "billing_account_id" {
  description = "Billing account ID to link to the new project, not a credential."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}$", var.billing_account_id))
    error_message = "Use the billing account ID in XXXXXX-XXXXXX-XXXXXX format."
  }
}
