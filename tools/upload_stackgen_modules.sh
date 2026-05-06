#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --token <token> [--url <stackgen-url>] [--project <project-id>] [--provider aws|azurerm|gcp] [--templates name1,name2] [--repo-url <repo>] [--branch <branch>|--tag <tag>] [--version <ver>] [--overwrite-version] [--parallel <N>]"
  exit 1
}

TOKEN=""
STACKGEN_URL=""
PROJECT_ID=""
TEMPLATE_TYPES=""
REPO_URL=""
BRANCH=""
VERSION=""
OVERWRITE_VERSION=false
TAG=""
PROVIDER_FILTER=""
PARALLEL_JOBS=10
MAX_RETRIES=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token) TOKEN="${2:-}"; shift 2 ;;
    --url) STACKGEN_URL="${2:-}"; shift 2 ;;
    --project) PROJECT_ID="${2:-}"; shift 2 ;;
    --templates) TEMPLATE_TYPES="${2:-}"; shift 2 ;;
    --repo-url) REPO_URL="${2:-}"; shift 2 ;;
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --tag) TAG="${2:-}"; shift 2 ;;
    --version) VERSION="${2:-}"; shift 2 ;;
    --overwrite-version) OVERWRITE_VERSION=true; shift ;;
    --provider) PROVIDER_FILTER="${2:-}"; shift 2 ;;
    --parallel) PARALLEL_JOBS="${2:-}"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$TOKEN" ]]; then
  usage
fi

if [[ -n "$BRANCH" && -n "$TAG" ]]; then
  echo "Error: use only one of --branch or --tag." >&2
  exit 1
fi

if [[ -z "$REPO_URL" && ( -n "$BRANCH" || -n "$TAG" ) ]]; then
  echo "Warning: --branch/--tag provided without --repo-url. The CLI may ignore them." >&2
fi

export STACKGEN_TOKEN="$TOKEN"
if [[ -n "$STACKGEN_URL" ]]; then
  export STACKGEN_URL="$STACKGEN_URL"
fi

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "$PROVIDER_FILTER" ]]; then
  PROVIDERS=("$PROVIDER_FILTER")
  echo "Filtering to provider: $PROVIDER_FILTER"
else
  PROVIDERS=(aws azurerm gcp)
fi

MODULES=()

if [[ -n "$TEMPLATE_TYPES" ]]; then
  IFS=',' read -r -a FILTERS <<< "$TEMPLATE_TYPES"
  for tmpl in "${FILTERS[@]}"; do
    tmpl="$(echo "$tmpl" | xargs)"
    found=false
    for provider in "${PROVIDERS[@]}"; do
      candidate="${BASE_DIR}/${provider}/${tmpl}"
      if [[ -d "$candidate" ]]; then
        MODULES+=("$candidate")
        found=true
        break
      fi
    done
    if [[ "$found" == false ]]; then
      echo "Warning: template type not found: $tmpl" >&2
    fi
  done
else
  for provider in "${PROVIDERS[@]}"; do
    if [[ -d "${BASE_DIR}/${provider}" ]]; then
      while IFS= read -r -d '' dir; do
        MODULES+=("$dir")
      done < <(find "${BASE_DIR}/${provider}" -mindepth 1 -maxdepth 1 -type d -print0)
    fi
  done
fi

if [[ ${#MODULES[@]} -eq 0 ]]; then
  echo "No modules found to upload." >&2
  exit 1
fi

TOTAL=${#MODULES[@]}

if [[ -n "$PROJECT_ID" ]]; then
  echo "Uploading ${TOTAL} module(s) to project ${PROJECT_ID} (parallelism: ${PARALLEL_JOBS})..."
else
  echo "Uploading ${TOTAL} module(s) (parallelism: ${PARALLEL_JOBS})..."
fi

# --- Temp files for thread-safe progress tracking ---
TMPDIR_UPLOAD="$(mktemp -d)"
COUNTER_FILE="${TMPDIR_UPLOAD}/counter"
FAIL_LOG="${TMPDIR_UPLOAD}/failures.log"
SKIP_LOG="${TMPDIR_UPLOAD}/skipped.log"
SUCCESS_LOG="${TMPDIR_UPLOAD}/success.log"
LOCK_FILE="${TMPDIR_UPLOAD}/counter.lock"
echo "0" > "$COUNTER_FILE"
: > "$FAIL_LOG"
: > "$SKIP_LOG"
: > "$SUCCESS_LOG"

cleanup() { rm -rf "$TMPDIR_UPLOAD"; }
trap cleanup EXIT

# Export shared config so subshells (via xargs) can access them
export _UPL_REPO_URL="$REPO_URL"
export _UPL_BRANCH="$BRANCH"
export _UPL_TAG="$TAG"
export _UPL_PROJECT_ID="$PROJECT_ID"
export _UPL_VERSION="$VERSION"
export _UPL_OVERWRITE_VERSION="$OVERWRITE_VERSION"
export _UPL_TOTAL="$TOTAL"
export _UPL_COUNTER_FILE="$COUNTER_FILE"
export _UPL_FAIL_LOG="$FAIL_LOG"
export _UPL_SKIP_LOG="$SKIP_LOG"
export _UPL_SUCCESS_LOG="$SUCCESS_LOG"
export _UPL_LOCK_FILE="$LOCK_FILE"
export _UPL_MAX_RETRIES="$MAX_RETRIES"

# --- Per-module upload function (runs in subshell via xargs) ---
upload_one_module() {
  local module="$1"
  local providerFolder name provider

  providerFolder="$(basename "$(dirname "$module")")"
  name="$(basename "$module")"
  provider="$providerFolder"
  if [[ "$providerFolder" == "azurerm" ]]; then
    provider="azure"
  fi

  # Build the command
  local cmd=(stackgen upload custom-modules "$module" --provider "$provider" --name "$name" --subdir="$providerFolder/$name")
  [[ -n "$_UPL_REPO_URL" ]]    && cmd+=(--repo-url "$_UPL_REPO_URL")
  [[ -n "$_UPL_BRANCH" ]]      && cmd+=(--branch "$_UPL_BRANCH")
  [[ -n "$_UPL_TAG" ]]         && cmd+=(--tag "$_UPL_TAG")
  [[ -n "$_UPL_PROJECT_ID" ]]  && cmd+=(--project "$_UPL_PROJECT_ID")
  [[ -n "$_UPL_VERSION" ]]     && cmd+=(--version "$_UPL_VERSION")
  [[ "$_UPL_OVERWRITE_VERSION" == true ]] && cmd+=(--overwrite-version)

  # Retry loop with exponential backoff
  local attempt=0 output status
  while (( attempt < _UPL_MAX_RETRIES )); do
    attempt=$((attempt + 1))
    output="$("${cmd[@]}" 2>&1)" && status=0 || status=$?

    if [[ $status -eq 0 ]]; then
      break
    fi

    # "version already exists" is not a retryable error — skip immediately
    if echo "$output" | grep -qi "version name already exists"; then
      status=0
      break
    fi

    # On last attempt, don't sleep
    if (( attempt < _UPL_MAX_RETRIES )); then
      local delay=$(( 2 ** (attempt - 1) ))
      sleep "$delay"
    fi
  done

  # Atomic counter increment (mkdir is atomic across processes on both Linux & macOS)
  local count
  while ! mkdir "$_UPL_LOCK_FILE" 2>/dev/null; do :; done
  count=$(( $(cat "$_UPL_COUNTER_FILE") + 1 ))
  echo "$count" > "$_UPL_COUNTER_FILE"
  rmdir "$_UPL_LOCK_FILE"

  # Report result
  if [[ $status -eq 0 ]]; then
    if echo "$output" | grep -qi "version name already exists"; then
      echo "[${count}/${_UPL_TOTAL}] ⊘ ${provider}/${name} (skipped: version exists)"
      echo "${provider}/${name}" >> "$_UPL_SKIP_LOG"
    else
      echo "[${count}/${_UPL_TOTAL}] ✓ ${provider}/${name}"
      echo "${provider}/${name}" >> "$_UPL_SUCCESS_LOG"
    fi
  else
    echo "[${count}/${_UPL_TOTAL}] ✗ ${provider}/${name} (FAILED after ${attempt} attempts)"
    echo "${provider}/${name}: ${output}" >> "$_UPL_FAIL_LOG"
  fi
}
export -f upload_one_module

# --- Run uploads in parallel ---
printf '%s\n' "${MODULES[@]}" | xargs -P "$PARALLEL_JOBS" -I {} bash -c 'upload_one_module "$@"' _ {}

# --- Summary ---
SUCCESS_COUNT=$(wc -l < "$SUCCESS_LOG" | tr -d ' ')
SKIP_COUNT=$(wc -l < "$SKIP_LOG" | tr -d ' ')
FAIL_COUNT=$(wc -l < "$FAIL_LOG" | tr -d ' ')

echo ""
echo "===== Upload Summary ====="
echo "  Succeeded: ${SUCCESS_COUNT}"
echo "  Skipped:   ${SKIP_COUNT} (version already exists)"
echo "  Failed:    ${FAIL_COUNT}"
echo "  Total:     ${TOTAL}"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo ""
  echo "===== Failed Modules ====="
  cat "$FAIL_LOG"
  echo ""
  echo "Done with errors."
  exit 1
fi

echo ""
echo "Done."
