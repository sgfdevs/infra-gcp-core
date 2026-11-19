# infra-gcp-core

Provisions SGFDEVS shared GCP foundation resources, including projects, APIs, service accounts, and workload identity federation.

## Scope
- Owns: GCP projects and billing associations.
- Owns: API enablement and application service accounts.
- Owns: GitHub Actions workload identity federation and service-account access.

## Structure
- `src/tf/`: OpenTofu resources for projects, APIs, and IAM.
- `.github/workflows/`: Validation workflow for OpenTofu changes.

## Run
Copy `.envrc.example` to `.envrc`. Set the AWS profile and fill in the GCP project ID and billing account ID. Set `TF_VAR_project_parent` to a JSON object with either `organization_id` or `folder_id`, or use `'{}'` for a project without an organization.

```bash
source ./.envrc
gcloud auth application-default login
aws sso login --profile "$AWS_DEFAULT_PROFILE"

make help
make tf-init
make tf-plan
make tf-apply
make tf-output
```

## Operating constraints
- Uses the S3 and DynamoDB state backend managed by `infra-aws-core`; apply that stack first.
- Projects are created by OpenTofu, not manually beforehand.
- Applies are manual/local; CI runs validation only.
- Use short-lived credentials, not service-account keys.
- For Play publishing, invite the service account in Play Console with app-specific **View app information (read-only)** and **Release apps to testing tracks** permissions. Grant production release permission only when needed; do not grant account-wide access.
