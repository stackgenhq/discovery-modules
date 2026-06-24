# Tools

This directory contains helper assets for publishing and maintaining StackGen discovery modules. Use this guide as the canonical contributor reference for uploading modules with `upload_stackgen_modules.sh`.

## Prerequisites

Before you upload modules, make sure you have:

- The `stackgen` CLI installed and available on your `PATH`.
- A StackGen token that can be passed with `--token` or exported as `STACKGEN_TOKEN` for the CLI session.
- A StackGen base URL for your environment when you are not using the CLI default configuration.
- Optional: a GitHub token from `gh auth token` or another SCM credential if your StackGen environment expects SCM-related authentication during upload.

## Quick start

Run a dry, limited upload first by targeting only the module folders you want to publish and confirming the repo metadata you plan to attach. The script discovers provider and module names from the directory you select, then passes those values through to `stackgen upload custom-modules`.

### Upload one AWS module

Upload only the `aws_s3_bucket` module from the repository root:

```bash
./tools/upload_stackgen_modules.sh \
  --token "$STACKGEN_TOKEN" \
  --url "https://main.dev.stackgen.com" \
  --templates "aws_s3_bucket" \
  --repo-url "https://github.com/stackgenhq/discovery-modules" \
  --branch "main"
```

### Upload one GCP module

Upload only the `google_storage_bucket` module:

```bash
./tools/upload_stackgen_modules.sh \
  --token "$STACKGEN_TOKEN" \
  --url "https://main.dev.stackgen.com" \
  --templates "google_storage_bucket" \
  --repo-url "https://github.com/stackgenhq/discovery-modules" \
  --branch "main"
```

## Flag reference

`upload_stackgen_modules.sh` accepts the following workflow inputs. Some values map directly to script flags, while others are inferred by the script before it calls `stackgen upload custom-modules`.

| Input | How it is used |
| --- | --- |
| `--provider` | Not a script flag. The script derives the provider for each module from the parent folder (`aws`, `azurerm`, or `gcp`) and passes that derived value to the StackGen CLI. `azurerm` modules are uploaded as provider `azure`. |
| `--name` | Not a script flag. The script derives the module name from the selected directory name and passes it to the StackGen CLI for each upload. |
| `--templates` | Comma-separated list of module folder names to upload. Use this to limit the run to one or more specific modules. Without it, the script uploads every immediate module directory under `aws/`, `azurerm/`, and `gcp/`. |
| `--repo-url` | Optional repository URL recorded with the uploaded module for source tracking. Pair this with `--branch` or `--tag` when you want StackGen to reference a specific source ref. |
| `--branch` | Optional Git branch name to associate with the uploaded module. Use either `--branch` or `--tag`, not both. |
| `--tag` | Optional Git tag to associate with the uploaded module. Use either `--tag` or `--branch`, not both. |
| `--project` | Optional StackGen project ID. When set, uploads use project scope; otherwise they use tenant scope. |
| `--dry-run` | No native script flag exists today. For a safe rehearsal, run with `--templates` to limit scope, review the module list and repo metadata first, and confirm the command inputs before doing a full upload. |

### Additional script flags

These flags are required for the wrapper script itself even though they were not part of the upload workflow checklist above:

| Flag | Required | Description |
| --- | --- | --- |
| `--token` | Yes | StackGen authentication token used by the CLI. |
| `--url` | No | StackGen base URL to export as `STACKGEN_URL` for the upload session. |

## Troubleshooting

- Start with a small, filtered run first. Use `--templates` to target one module at a time before attempting a broader upload.
- If you see `Unknown option`, verify the flag name and remember that `--provider`, `--name`, and `--dry-run` are workflow concepts documented here, not direct wrapper-script flags.
- If the script exits with `Error: use only one of --branch or --tag.`, remove one of those source reference flags and retry.
- If you see `Warning: --branch/--tag provided without --repo-url. The CLI may ignore them.`, rerun with `--repo-url` so the source reference is attached correctly.
- If StackGen reports `version name already exists`, the script skips that module and continues; confirm whether you intended to republish an existing version.
- If the `stackgen` command is not found or authentication fails, verify your CLI installation, token, environment URL, and any optional SCM credentials such as `gh auth token`.
