# Verification Completion Email Notification

## Objective

Send one email notification after the project verification stage completes successfully.

## Completion gate

The notification is eligible only when all required verification checks for the selected release commit have completed successfully. At minimum this includes:

- `RTL Regression`
- `Synthesis Check`
- all verification tasks for the release marked complete in `.agent/roadmap.yml`

A failed, cancelled, skipped, pending, or missing required check must block notification.

## Delivery

Default recipient:

```text
tony_lee@syntronix.com.tw
```

The email must include:

- repository and release version
- commit SHA
- verification completion time
- summary of directed, boundary, backpressure, random, error and timeout tests
- links to the GitHub commit, workflow runs and available artifacts
- known verification limitations or manual sign-off items

## Duplicate prevention

The workflow must send no more than one completion email for the same release commit. A Git tag, release marker, issue label, artifact marker, or equivalent durable state must be used to prevent duplicate delivery.

## Credentials

SMTP credentials must be stored only as GitHub Actions secrets. They must never be committed to the repository or printed in workflow logs.

Recommended secrets:

- `SMTP_SERVER`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `VERIFICATION_EMAIL_TO`

## Acceptance criteria

- notification runs only after successful verification completion
- failure or incomplete verification does not send email
- duplicate notification for the same commit is prevented
- missing SMTP secrets causes a clear skipped or failed delivery status without exposing credentials
- a manual `workflow_dispatch` test mode is available
