output "project_id" {
  description = "GCP project ID."
  value       = google_project.core.project_id
}

output "project_number" {
  description = "Numeric GCP project number used in workload identity resource names."
  value       = google_project.core.number
}

output "method_play_service_account_email" {
  description = "Invite this email in Play Console for the Method app only."
  value       = google_service_account.method_play.email
}

output "method_play_workload_identity_provider" {
  description = "Full provider resource name for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.method_play_github.name
}
