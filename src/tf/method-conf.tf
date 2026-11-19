locals {
  method_conf_project_id = "sgfdevs-method-conf"
  method_repository      = "sgfdevs/method_conf_app"
  method_repository_id   = "237699189"
  sgfdevs_owner_id       = "53604170"
  method_deploy_workflow = "${local.method_repository}/.github/workflows/play-deploy.yml"
  method_release_ref     = "refs/heads/main"
}

resource "google_project" "method_conf" {
  project_id      = local.method_conf_project_id
  name            = local.method_conf_project_id
  org_id          = var.gcp_organization_id
  billing_account = var.gcp_billing_account_id
  deletion_policy = "PREVENT"

  labels = {
    managed-by = "opentofu"
  }
}

resource "google_project_service" "method_conf_service_usage" {
  project            = google_project.method_conf.project_id
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "method_conf_api" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "androidpublisher.googleapis.com",
  ])

  project            = google_project.method_conf.project_id
  service            = each.value
  disable_on_destroy = false

  depends_on = [google_project_service.method_conf_service_usage]
}

resource "google_service_account" "method_play" {
  project      = google_project.method_conf.project_id
  account_id   = "method-play-store"
  display_name = "Method Play Store"
  description  = "Method Android release uploads. App permissions are managed in Play Console."

  depends_on = [google_project_service.method_conf_api["iam.googleapis.com"]]
}

resource "google_iam_workload_identity_pool" "method_play" {
  project                   = google_project.method_conf.project_id
  workload_identity_pool_id = "method-play"
  display_name              = "Method Play releases"
  description               = "GitHub OIDC for the manual Method Play deployment workflow only."

  depends_on = [google_project_service.method_conf_api["iam.googleapis.com"]]
}

resource "google_iam_workload_identity_pool_provider" "method_play_github" {
  project                            = google_project.method_conf.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.method_play.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "Method GitHub releases"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository_id"    = "assertion.repository_id"
    "attribute.job_workflow_ref" = "'job_workflow_ref' in assertion ? assertion.job_workflow_ref : assertion.workflow_ref"
  }

  attribute_condition = <<-CEL
    assertion.repository_owner_id == "${local.sgfdevs_owner_id}" &&
    assertion.repository_id == "${local.method_repository_id}" &&
    assertion.repository == "${local.method_repository}" &&
    assertion.event_name == "workflow_dispatch" &&
    assertion.ref == ${jsonencode(local.method_release_ref)} &&
    assertion.workflow_ref == ${jsonencode("${local.method_deploy_workflow}@${local.method_release_ref}")} &&
    attribute.job_workflow_ref == assertion.workflow_ref
  CEL

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "method_play_github" {
  service_account_id = google_service_account.method_play.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.method_play.name}/attribute.repository_id/${local.method_repository_id}"

  depends_on = [
    google_iam_workload_identity_pool_provider.method_play_github,
    google_project_service.method_conf_api["iamcredentials.googleapis.com"],
    google_project_service.method_conf_api["sts.googleapis.com"],
  ]
}
