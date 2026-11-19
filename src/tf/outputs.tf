output "method_conf_project_id" {
  description = "GCP project ID for Method Conf."
  value       = google_project.method_conf.project_id
}

output "method_conf_project_number" {
  description = "Numeric Method Conf project number used in workload identity resource names."
  value       = google_project.method_conf.number
}

output "method_play_service_account_email" {
  description = "Invite this email in Play Console for the Method app only."
  value       = google_service_account.method_play.email
}

output "method_play_workload_identity_provider" {
  description = "Full provider resource name for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.method_play_github.name
}
