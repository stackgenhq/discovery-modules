# Tools

Helper scripts for managing and publishing StackGen discovery modules.

---

## upload_stackgen_modules.sh

Bulk-uploads Terraform module directories to the StackGen custom module registry using the `stackgen` CLI. Supports parallel execution for fast uploads of large module libraries.

### Prerequisites

- **`stackgen` CLI** installed and available on `$PATH`
- A valid **StackGen API token** (passed via `--token`)
- Modules organized under `aws/`, `azurerm/`, and/or `gcp/` provider directories

### Usage

```bash
./tools/upload_stackgen_modules.sh --token <token> [OPTIONS]
```

### Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--token <token>` | **Yes** | — | StackGen API token for authentication |
| `--url <url>` | No | CLI default | StackGen instance URL (e.g., `https://seti.cloud.stackgen.com`) |
| `--project <id>` | No | — | Project ID for auth context (does **not** scope module visibility — modules are always org-wide) |
| `--provider <name>` | No | All providers | Filter to a single provider: `aws`, `azurerm`, or `gcp` |
| `--templates <list>` | No | All modules | Comma-separated list of module names to upload (e.g., `aws_s3_bucket,aws_iam_role`) |
| `--repo-url <url>` | No | — | Git repository URL for StackGen to reference (e.g., `https://github.com/org/repo`) |
| `--branch <branch>` | No | — | Git branch to reference. Mutually exclusive with `--tag`. Requires `--repo-url` |
| `--tag <tag>` | No | — | Git tag to reference. Mutually exclusive with `--branch`. Requires `--repo-url` |
| `--version <ver>` | No | `1.0` (CLI default) | Module version string |
| `--overwrite-version` | No | `false` | Overwrite an existing version instead of skipping |
| `--parallel <N>` | No | `10` | Number of concurrent uploads |

### Examples

#### Upload all modules (all providers)

```bash
./tools/upload_stackgen_modules.sh \
  --token "$STACKGEN_TOKEN" \
  --url "https://seti.cloud.stackgen.com"
```

#### Upload only AWS modules

```bash
./tools/upload_stackgen_modules.sh \
  --token "$STACKGEN_TOKEN" \
  --url "https://seti.cloud.stackgen.com" \
  --provider aws
```

#### Upload specific modules by name

```bash
./tools/upload_stackgen_modules.sh \
  --token "$STACKGEN_TOKEN" \
  --url "https://seti.cloud.stackgen.com" \
  --templates "aws_s3_bucket,aws_iam_role,aws_lambda_function"
```

#### Upload from a specific branch with repo reference

```bash
./tools/upload_stackgen_modules.sh \
  --token "$STACKGEN_TOKEN" \
  --url "https://seti.cloud.stackgen.com" \
  --repo-url "https://github.com/stackgenhq/discovery-modules" \
  --branch "main"
```

#### Overwrite existing module versions

```bash
./tools/upload_stackgen_modules.sh \
  --token "$STACKGEN_TOKEN" \
  --url "https://seti.cloud.stackgen.com" \
  --overwrite-version
```

#### Bump to a new version

```bash
./tools/upload_stackgen_modules.sh \
  --token "$STACKGEN_TOKEN" \
  --url "https://seti.cloud.stackgen.com" \
  --version "2.0" \
  --provider aws
```

#### Increase parallelism for faster uploads

```bash
./tools/upload_stackgen_modules.sh \
  --token "$STACKGEN_TOKEN" \
  --url "https://seti.cloud.stackgen.com" \
  --parallel 20
```

### How it works

1. **Module discovery** — Scans `aws/`, `azurerm/`, and `gcp/` directories (or a single provider if `--provider` is set) for subdirectories. Each subdirectory is treated as one module. If `--templates` is provided, only the named modules are uploaded.

2. **Parallel dispatch** — Modules are uploaded concurrently using `xargs -P`. The default concurrency is 10, tunable with `--parallel`.

3. **Retry with backoff** — Each module upload is retried up to 3 times with exponential backoff (1s → 2s → 4s) for transient API failures. "Version already exists" errors are detected immediately and skipped without retrying.

4. **Provider mapping** — The provider name is derived from the parent directory (`aws` → `aws`, `gcp` → `gcp`). The `azurerm` directory is mapped to `azure` since the StackGen CLI uses `azure` as the provider name.

5. **Progress tracking** — A thread-safe atomic counter (using `mkdir`-based spinlocking) provides real-time `[N/Total]` progress output, even across parallel subshells. Works on both macOS (BSD) and Linux (GNU).

6. **Summary report** — After all uploads complete, a structured summary shows succeeded, skipped (version exists), and failed counts. Failed module names and error messages are listed. The script exits non-zero only if there were failures.

### Output example

```
Uploading 817 module(s) (parallelism: 10)...
[1/817] ✓ aws/aws_s3_bucket
[2/817] ✓ aws/aws_iam_role
[3/817] ⊘ aws/aws_lambda_function (skipped: version exists)
[4/817] ✗ aws/aws_bad_module (FAILED after 3 attempts)
...

===== Upload Summary =====
  Succeeded: 815
  Skipped:   1 (version already exists)
  Failed:    1
  Total:     817

===== Failed Modules =====
aws/aws_bad_module: Error: invalid module configuration
```

---

## bulk-tag-modules.sh

Creates `v1.0.0` Git tags for all module subdirectories. These tags are required by the `module-backfill.yml` GitHub Actions workflow to discover and upload modules.

### Usage

```bash
./tools/bulk-tag-modules.sh              # Dry run — shows what would be tagged
./tools/bulk-tag-modules.sh --apply      # Creates tags locally
./tools/bulk-tag-modules.sh --apply --push  # Creates tags and pushes to remote
```

### Tag format

```
<module-subdirectory-name>-v1.0.0
```

Examples: `aws_s3_bucket-v1.0.0`, `azurerm_resource_group-v1.0.0`, `google_compute_instance-v1.0.0`

---

## Other files

| File | Description |
|------|-------------|
| `stackgen_yaml_schema.json` | JSON Schema for `.stackgen/stackgen.yaml` files. Use for editor validation and CI linting. |
| `dummy.yaml` | Sample fixture input for development and testing. |
