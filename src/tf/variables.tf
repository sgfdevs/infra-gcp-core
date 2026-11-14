variable "project_id" {
  description = "Approved, globally unique GCP project ID to create."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Use a valid 6-30 character GCP project ID."
  }
}

variable "project_name" {
  description = "GCP project display name."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.project_name) >= 4 && length(var.project_name) <= 30
    error_message = "The project display name must contain 4-30 characters."
  }
}

variable "project_parent" {
  description = "Set an organization ID or folder ID. Use {} explicitly for no organization."
  type = object({
    organization_id = optional(string)
    folder_id       = optional(string)
  })
  nullable = false

  validation {
    condition = (
      !(var.project_parent.organization_id != null && var.project_parent.folder_id != null) &&
      (var.project_parent.organization_id == null || can(regex("^[0-9]+$", var.project_parent.organization_id))) &&
      (var.project_parent.folder_id == null || can(regex("^[0-9]+$", var.project_parent.folder_id)))
    )
    error_message = "Specify at most one numeric organization_id or folder_id, or use {} for no organization."
  }
}

variable "billing_account_id" {
  description = "Billing account ID to link to the new project, not a credential."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}$", var.billing_account_id))
    error_message = "Use the billing account ID in XXXXXX-XXXXXX-XXXXXX format."
  }
}

variable "method_release_branch" {
  description = "Approved branch for prepare-release.yml to call android-release.yml."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(regex("^[A-Za-z0-9_/-]+([.][A-Za-z0-9_/-]+)*$", var.method_release_branch)) &&
      !startswith(var.method_release_branch, "/") &&
      !endswith(var.method_release_branch, "/") &&
      !strcontains(var.method_release_branch, "//") &&
      !endswith(var.method_release_branch, ".lock")
    )
    error_message = "Use a branch name, not a full ref. Dots, slashes, hyphens and underscores are supported."
  }
}
