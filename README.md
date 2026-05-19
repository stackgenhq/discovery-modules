# discovery-modules

This repository holds **StackGen discovery modules**: one Terraform template per cloud resource (and related data sources), organized by provider. Each module is a small, self-contained package StackGen can use for discovery, custom modules, and UI metadata.

## What’s in here

- **`aws/`** — AWS resource and data-source templates (Terraform `aws_*` style).
- **`azurerm/`** — Azure resource templates (Terraform `azurerm_*` style).
- **`gcp/`** — Google Cloud resource templates (Terraform `google_*` style).

Each directory under those roots is a single module: Terraform files (typically a resource- or data-named `.tf` plus `versions.tf`) and a **`.stackgen/stackgen.yaml`** file describing how StackGen should present and wire the template.

## Terraform and provider versions (`main` branch)

The following are the **`required_version` / `required_providers` constraints** declared in each module’s `versions.tf` on the default branch. They are compatibility ranges (not pinned releases); Terraform selects provider versions that satisfy them.

| Component | Constraint | Registry source |
|-----------|------------|-----------------|
| Terraform CLI | `>= 1.0.0, < 2.0.0` | — |
| AWS | `~> 5.0` | `hashicorp/aws` |
| Azure (Resource Manager) | `~> 3.9` | `hashicorp/azurerm` |
| Microsoft Entra ID | `~> 3.1.0` | `hashicorp/azuread` |
| Google Cloud | `~> 6.0` | `hashicorp/google` |

Most modules declare only the provider for their cloud API. A subset of **`azurerm/`** templates that manage Entra ID (Azure AD) resources also declare **`azuread`** with `~> 3.1.0` in addition to **`azurerm`**. Individual modules may occasionally diverge; each module’s **`versions.tf`** is authoritative. See [Versioning and provider compatibility](#versioning-and-provider-compatibility) for how Git tags relate to these constraints.

The [`tools/`](tools/) directory contains scripts and helpers to **publish these modules to StackGen** and to regenerate StackGen YAML when the schema or layouts change. See [Tools](#tools) for a file-by-file index.

## Prerequisites for upload

- StackGen CLI (`stackgen`) installed and on your `PATH` (install steps depend on your StackGen environment).
- A StackGen token (passed through to the CLI; often the same credential the `stackgen` command uses).
- Optional: `gh auth token` (or another SCM token) if your workflow sets `SCM_*` env vars for the CLI.

## Uploading to StackGen

Uploads use the **StackGen CLI**. The script **`tools/upload_stackgen_modules.sh`** bulk-uploads modules by running **`stackgen upload custom-modules`** in parallel (with `--provider`, `--name`, and optional `--repo-url` / `--branch` / `--tag` / `--project`). See [`tools/README.md`](tools/README.md) for full documentation, flag reference, and usage examples.

Modules scanned are the immediate subdirectories of **`aws/`**, **`azurerm/`**, and **`gcp/`**, with optional `--templates` filtering.

### Basic upload

```bash

./tools/upload_stackgen_modules.sh \
  --token "YOUR_STACKGEN_TOKEN" \
  --url "https://main.dev.stackgen.com" \
  --repo-url "https://github.com/stackgenhq/discovery-modules" \
  --branch "main"
```

### Options

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--token` | Yes | — | StackGen authentication token |
| `--url` | No | CLI default | StackGen base URL (e.g., `https://seti.cloud.stackgen.com`) |
| `--project` | No | — | Project ID for auth context (modules are always org-wide) |
| `--provider` | No | All | Filter to a single provider: `aws`, `azurerm`, or `gcp` |
| `--templates` | No | All modules | Comma-separated module folder names (e.g. `aws_ec2,aws_s3`) |
| `--repo-url` | No | — | Repository URL for source tracking in StackGen |
| `--branch` | No | — | Git branch name (mutually exclusive with `--tag`; requires `--repo-url`) |
| `--tag` | No | — | Git tag name (mutually exclusive with `--branch`; requires `--repo-url`) |
| `--version` | No | `1.0` | Module version string |
| `--overwrite-version` | No | `false` | Overwrite an existing version instead of skipping |
| `--parallel` | No | `10` | Number of concurrent uploads |

### Behavior

- **Minimal input**: Only `--token` is strictly required by the script.
- **Parallel uploads**: Modules are uploaded concurrently using `xargs -P` (default: 10 workers, tunable with `--parallel`).
- **Retry with backoff**: Each upload is retried up to 3 times with exponential backoff (1s → 2s → 4s) for transient failures.
- **Provider mapping**: `azurerm` modules are uploaded with StackGen provider **`azure`**.
- **Skip existing**: If the CLI reports that the version name already exists, that module is skipped (use `--overwrite-version` to force).
- **Fail-at-end**: Failures are collected and reported in a summary after all uploads complete, rather than stopping on the first error.
- **Cross-platform**: Works on both macOS (BSD) and Linux (GNU).

## Tools

Utilities for **publishing** and **maintaining** discovery modules. See [`tools/README.md`](tools/README.md) for full documentation.

| Script | Description |
|--------|-------------|
| **`upload_stackgen_modules.sh`** | Bulk-uploads modules to StackGen with parallel execution, retries, and progress tracking. See [Uploading to StackGen](#uploading-to-stackgen). |
| **`bulk-tag-modules.sh`** | Creates `v1.0.0` Git tags for all module subdirectories (dry-run by default). Required by the `module-backfill.yml` workflow. |
| **`stackgen_yaml_schema.json`** | JSON Schema for `.stackgen/stackgen.yaml` (validation and editor support). |
| **`dummy.yaml`** | Sample / fixture input for development. |

## Versioning and provider compatibility

This repository is a **monorepo**: Git tags (and branches) refer to a **single commit for the entire tree**, not per-module versions. Module sources that use Git typically pin a path and a ref, for example:

```text
git::https://github.com/example/discovery-modules.git//gcp/google_storage_bucket?ref=v1.2.3
```

**Where compatibility is defined**

| Concern | Where it lives |
|--------|----------------|
| Terraform and provider versions the module expects | Each module’s `versions.tf` (`required_version`, `required_providers`) |
| Which snapshot of the repo to use | Git **tag** or **branch** (`ref=`) |

**Tagging convention (semantic versioning)**

Use tags of the form `vMAJOR.MINOR.PATCH` on the repository. Summarize user-facing and breaking changes per tag in **[CHANGELOG.md](CHANGELOG.md)** when you publish a release (especially provider baseline bumps and incompatible module API changes).

- **MAJOR** — Breaking changes, including raising the minimum **major** version of a cloud provider (for example moving AWS from `~> 5.0` to `~> 6.0` in `required_providers`), or incompatible input/output changes.
- **MINOR** — New modules, new optional variables, or backward-compatible behavior.
- **PATCH** — Bug fixes that preserve the module contract.

**When the repo moves to a new provider major**

If `main` raises a minimum provider version (for example AWS `~> 5.0` to `~> 6.0`), stay on an **older Git tag or branch** until your root module can match the new `required_providers` in this repo. Tags apply to the whole monorepo; you pin `ref` to the snapshot you need. **CHANGELOG.md** and GitHub/Git release notes should call out provider baseline changes when new tags are cut.

## Contributing

We welcome contributions. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening issues or pull requests.

In short: keep Terraform and **`.stackgen/stackgen.yaml`** in sync, validate metadata against **`tools/stackgen_yaml_schema.json`**, and use the tools under **`tools/`** where appropriate.

## License

This project is licensed under the Apache License 2.0 — see [LICENSE](LICENSE).
