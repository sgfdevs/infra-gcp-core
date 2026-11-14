resource "google_project" "core" {
  project_id      = var.project_id
  name            = var.project_name
  org_id          = var.project_parent.organization_id
  folder_id       = var.project_parent.folder_id
  billing_account = var.billing_account_id
  deletion_policy = "PREVENT"

  labels = {
    managed-by = "opentofu"
  }
}

resource "google_project_service" "service_usage" {
  project            = google_project.core.project_id
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "api" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "androidpublisher.googleapis.com",
  ])

  project            = google_project.core.project_id
  service            = each.value
  disable_on_destroy = false

  depends_on = [google_project_service.service_usage]
}
