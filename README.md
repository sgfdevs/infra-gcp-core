# infra-gcp-core

SGFDEVS GCP foundation, initially for keyless Method Android releases to Google Play.

## Scope and layout

- `src/tf/` creates the GCP project itself through `google_project.core`, links billing, enables the Android Publisher API and workload identity APIs, and creates the `method-play-store` service account. Do not create this project manually first.
- A dedicated `method-play` workload identity pool trusts GitHub OIDC for `sgfdevs/method_conf_app` and its Android release workflow only.
- State uses the existing `infra-aws-core` S3 bucket `sgfdevs-infra-tf-state`, DynamoDB lock table `sgfdevs-infra-tflock`, and region `us-east-2`. This stack's key is `sgfdevs/infra-gcp-core/terraform.tfstate`. Do not use AWS core's state key or create another backend here.
- `.github/workflows/ci.yml` follows AWS core's validation-only workflow, with backend initialization disabled and the required `Terraform checks` result. No CI plan or apply, cloud credentials, or state access is configured.

Applies are manual/local. This stack does not create service-account keys, tokens, OAuth client secrets, GitHub secrets, or Play Console permissions. The Play service account has no GCP project roles. Its only IAM grant allows the restricted GitHub identity to impersonate it through `roles/iam.workloadIdentityUser`; `roles/iam.serviceAccountTokenCreator` is not needed for this flow.

## Required decisions

Obtain approval for these values before planning. No project, parent, billing account, or release branch is assumed:

- A globally unique project ID and project display name.
- A parent organization ID or folder ID. Use `project_parent = {}` only after explicitly choosing no organization.
- The billing account ID to associate with the new project.
- The branch allowed to dispatch `prepare-release.yml` and call `android-release.yml`.

Copy `src/tf/terraform.tfvars.example` to the ignored `src/tf/terraform.tfvars`, then replace the blanks. These inputs are identifiers, not credentials. The example intentionally cannot be used unchanged. An existing project must be reviewed and imported instead of attempting to create it again.

## Local authentication

Two separate logins are required. AWS protects state; Google authorizes resource management. A `gcloud` CLI login alone does not authenticate the OpenTofu Google provider.

These commands assume the Google Cloud CLI and AWS CLI are already available. This repository does not install global tools. If either CLI is missing, arrange installation separately before running the authentication commands.

```bash
gcloud auth login
gcloud auth application-default login

# Use your existing AWS IAM Identity Center profile, not access keys.
aws sso login --profile YOUR_AWS_PROFILE

cp .envrc.example .envrc
# Edit .envrc to select that AWS profile.
cp src/tf/terraform.tfvars.example src/tf/terraform.tfvars
# Fill in the approved identifiers and release branch.
```

`gcloud auth application-default login` stores user credentials outside this repo in the normal gcloud configuration directory. The Google provider discovers them as Application Default Credentials, or ADC. Never print, copy into this repo, or send anyone that file. Do not set `GOOGLE_APPLICATION_CREDENTIALS` to a service-account key. Remove stale credential-file overrides from your shell before using user ADC.

Do not set the not-yet-created project as the ADC quota project. Project creation is managed here, not a manual prerequisite. Some Google client-based APIs require a separate quota project for user ADC. If Google returns a missing-quota-project or API-consumer error during bootstrap, select an existing, approved project for that request accounting:

```bash
gcloud auth application-default set-quota-project YOUR_EXISTING_QUOTA_PROJECT_ID
# Also put this export in the ignored .envrc for the Google provider:
export GOOGLE_CLOUD_QUOTA_PROJECT=YOUR_EXISTING_QUOTA_PROJECT_ID
```

The provider needs the explicit environment variable for request accounting; setting only the quota project in the ADC file is not sufficient for this provider version. That requires `serviceusage.services.use`, normally `roles/serviceusage.serviceUsageConsumer`, on the quota project. It does not transfer ownership of the new project out of IaC. If no suitable project exists and Google requires one, stop and review the bootstrap approach with the administrator rather than manually creating the target project. After creation, this project can be selected for quota if the operator has the required permissions.

The bootstrap operator needs:

- Permission to create projects in the approved organization or folder, normally `roles/resourcemanager.projectCreator` there, or permission/quota to create a no-organization project.
- `roles/billing.user` on the selected billing account and permission to associate billing on the project. The provider also reads the billing account during plans.
- Permission on the created project to enable services, manage service accounts and their IAM policies, and administer workload identity pools. Typical roles are `roles/serviceusage.serviceUsageAdmin`, `roles/iam.serviceAccountAdmin`, and `roles/iam.workloadIdentityPoolAdmin`, plus project read access. Check inherited permissions or the creator's grants before assigning anything else. Do not grant these administrative roles to the Play service account.
- AWS access to read/write this stack's state object and use the shared DynamoDB lock table. Use an existing authorized operator profile; this repo does not add an AWS CI role.

If a separate quota/bootstrap project is used, an administrator must ensure it permits Resource Manager, Cloud Billing, and Service Usage API calls. If their APIs need enabling, that is a separate approved live change. Organization policies can restrict project creation, external identity federation, or billing association. Resolve those restrictions with the administrator rather than broadening this trust policy.

## Review and manual bootstrap

1. Review the `infra-gh` repository registration and parent `mani.yaml` inventory change separately. Applying `infra-gh` creates the GitHub repository with the usual infrastructure teams and `Terraform checks` ruleset. Its existing automation can apply on merge, so do not merge that registration until repository creation is approved. No remote repository creation or push is part of local preparation.
2. Confirm `infra-aws-core` has already created the state backend. Authenticate locally as above and fill in the approved inputs.
3. Initialize and inspect a saved plan:

   ```bash
   make help
   make tf-init
   make tf-validate
   make tf-format
   make tf-plan ARGS='-out=tfplan'
   make tf-show ARGS=tfplan
   ```

   Review the project parent, billing account, service-account IAM member, and provider condition. Plans live under `src/tf/`. Treat plans and state as private operational data. Do not upload them or use credential/token values as inputs. The project has `deletion_policy = "PREVENT"`; removing it or replacing its ID needs a separate review. Enabled APIs are left enabled when removed from state.
4. Only after explicit approval, apply that reviewed plan locally:

   ```bash
   make tf-apply ARGS=tfplan
   make tf-output
   ```

   IAM and workload identity changes may take several minutes to propagate. Outputs contain only identifiers: `project_id`, `project_number`, `method_play_service_account_email`, and `method_play_workload_identity_provider`.
5. A Play Console account owner or administrator must open **Users and permissions**, select **Invite new users**, and enter the `method_play_service_account_email` output. Under app permissions, add only the existing Method Android app. Verify the app's package ID before granting access. Do not grant account-wide access or administrator privileges.
6. For a testing-track uploader, grant the Method app's **View app information (read-only)** and **Release apps to testing tracks** permissions, then invite the service account. Grant **Release to production, exclude devices, and use Play App Signing** only if production deployment is explicitly intended. Add **Manage testing tracks and edit tester lists** only if automation manages tester lists or track settings. Store-listing uploads need separately reviewed **Manage store presence** permission. Do not grant financial, order/subscription, or user-management permissions for binary uploads.
7. Ensure the app already exists in Play Console, its initial manual upload/setup and Play App Signing requirements are satisfied, and its signing key/upload key matches the existing Android workflow. Play Console access is separate from GCP IAM; enabling the API or creating the service account does not grant app access. No project-linking step is required by the current Android Publisher API setup instructions.
8. Remove the local saved plan when finished. Keep credentials outside the repo and do not generate a service-account JSON key.

## Method workflow contract

The inspected checkout currently has no Fastlane or Google auth step. `android-release.yml` builds signed APK/AAB files and uploads them to GitHub releases. `prepare-release.yml` can dispatch from a branch, create platform tags, and call the Android workflow. The existing signing secrets remain necessary; federation replaces only the future Google Play API credential. This repo does not change that app checkout.

The provider accepts only the verified repository ID `237699189`, SGFDEVS owner ID `53604170`, and repository name `sgfdevs/method_conf_app`, with one of these identities:

- A `release` event with an `android/vX.Y.Z+BUILD` tag, executing `.github/workflows/android-release.yml` at that same tag ref.
- A `workflow_dispatch` event on the configured release branch, where `.github/workflows/prepare-release.yml` calls `.github/workflows/android-release.yml` at that same branch ref. The policy checks both the caller's `workflow_ref` and the reusable job's `job_workflow_ref`.

Pull requests, forks, other repos, other caller workflows, other branches for manual preparation, iOS tags, and unrelated jobs in the prepare workflow are rejected. GitHub OIDC retains the caller's event and ref during reusable calls; checking only the tag subject would break this release path. The reusable path cannot attest the `release_tag` input, so the Android workflow must keep validating that input and the checked-out version before authenticating or uploading. Only jobs in the Android workflow should request Google credentials.

Published-release runs trust the Android workflow stored at the release tag, not necessarily the configured preparation branch. Protect Android release tag creation and restrict who can publish releases and edit the two workflows. Branch and tag governance in the app repo remain a prerequisite; this stack does not configure them. Do not add another provider to this dedicated pool without reviewing all restrictions because the IAM principal set is pool-scoped.

In the later, separately reviewed app change:

- Grant `id-token: write` to the Android publishing job and to the caller of the reusable workflow, while retaining the existing `contents` access. The caller currently lacks this permission and a callee cannot elevate it.
- After checkout and as close as possible to the upload, run a reviewed, SHA-pinned `google-github-actions/auth` release with `workload_identity_provider`, `service_account`, and `project_id` set from this stack's outputs. These identifiers can be GitHub Actions variables, not secrets. Keep credentials-file creation and cleanup enabled.
- Use a Fastlane version whose Supply implementation supports `external_account` credentials or ADC discovery. Version `2.241.2` was checked for both. Let the Google auth library request `https://www.googleapis.com/auth/androidpublisher` through ADC via `GOOGLE_APPLICATION_CREDENTIALS`. Do not replace federation with a private-key JSON file or assume older Fastlane versions accept federation credentials.
- If generating an access-token output explicitly, request the Android Publisher scope rather than the action's default `cloud-platform` scope. Do not print a token, write it to OpenTofu inputs/state, or upload the generated `gha-creds-*.json` file. Exclude that file from source, caches, and artifacts; leave post-job cleanup enabled. Authenticate just before publishing to avoid expiration during the Flutter build.
- Choose and review the Play track and app-specific permissions before the first upload. Do not default a new publisher to production.

## Credential-free validation

From a fresh checkout, create an empty `.envrc` locally or copy `.envrc.example`. The backend-disabled checks do not need AWS or Google credentials:

```bash
make tf-init ARGS='-backend=false -input=false'
make tf-validate
make tf-format
```

This checks provider schemas and formatting, not live permissions, project availability, or token exchange. A real plan and end-to-end authentication check must wait for approved identifiers and access. Do not run apply in CI.

## References

- [Google Play Developer API setup](https://developers.google.com/android-publisher/getting_started)
- [Play Console app and account permissions](https://support.google.com/googleplay/android-developer/answer/9844686)
- [GitHub OIDC claims](https://docs.github.com/en/actions/reference/security/oidc)
- [Google GitHub Actions authentication](https://github.com/google-github-actions/auth)
- [Fastlane Supply credential handling, 2.241.2](https://github.com/fastlane/fastlane/blob/2.241.2/supply/lib/supply/client.rb)
