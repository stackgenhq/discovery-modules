#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --token <token> [--url <stackgen-url>] [--templates name1,name2] [--repo-url <repo>] [--branch <branch>|--tag <tag>]"
  exit 1
}

TOKEN=""
STACKGEN_URL=""
TEMPLATE_TYPES=""
REPO_URL=""
BRANCH=""
TAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token) TOKEN="${2:-}"; shift 2 ;;
    --url) STACKGEN_URL="${2:-}"; shift 2 ;;
    --templates) TEMPLATE_TYPES="${2:-}"; shift 2 ;;
    --repo-url) REPO_URL="${2:-}"; shift 2 ;;
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --tag) TAG="${2:-}"; shift 2 ;;
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
PROVIDERS=(aws azurerm gcp)

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

echo "Uploading ${#MODULES[@]} module(s)..."

for module in "${MODULES[@]}"; do
  providerFolder="$(basename "$(dirname "$module")")"
  name="$(basename "$module")"
  provider="$providerFolder"
  if [[ "$providerFolder" == "azurerm" ]]; then
    provider="azure"
  fi

  echo "-> Uploading ${provider}/${name}"
  cmd=(stackgen upload custom-modules "$module" --provider "$provider" --name "$name" --subdir="$providerFolder/$name")
  if [[ -n "$REPO_URL" ]]; then
    cmd+=(--repo-url "$REPO_URL")
  fi
  if [[ -n "$BRANCH" ]]; then
    cmd+=(--branch "$BRANCH")
  fi
  if [[ -n "$TAG" ]]; then
    cmd+=(--tag "$TAG")
  fi
  cmd+=(--scope tenant)
  set +e
  output="$("${cmd[@]}" 2>&1)"
  status=$?
  set -e
  if [[ $status -ne 0 ]]; then
    if echo "$output" | grep -qi "version name already exists"; then
      echo "-> Skipping ${provider}/${name}: version already exists"
      continue
    fi
    echo "$output" >&2
    exit $status
  fi
done

echo "Done."
