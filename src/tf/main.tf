locals {
  project_id = "sgfdevs-gcp-core"
}

resource "google_project" "core" {
  project_id      = local.project_id
  name            = "SGF Devs GCP Core"
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
