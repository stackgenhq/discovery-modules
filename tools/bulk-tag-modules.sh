#!/bin/bash
# bulk-tag-modules.sh
#
# Creates v1.0.0 tags for all module subdirectories in aws/, azurerm/, and gcp/.
# These tags are required for the module-backfill.yml workflow to discover and upload modules.
#
# Usage:
#   ./tools/bulk-tag-modules.sh              # Dry run (default) — shows what would be tagged
#   ./tools/bulk-tag-modules.sh --apply      # Creates tags locally
#   ./tools/bulk-tag-modules.sh --apply --push  # Creates tags and pushes to remote
#
# Tag format: <module-subdirectory-name>-v1.0.0
# Examples:
#   aws_s3_bucket-v1.0.0
#   azurerm_resource_group-v1.0.0
#   google_compute_instance-v1.0.0

set -euo pipefail

# Parse flags
APPLY=false
PUSH=false
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --push)  PUSH=true ;;
    --help|-h)
      echo "Usage: $0 [--apply] [--push]"
      echo ""
      echo "  --apply  Create tags locally (without this flag, dry run only)"
      echo "  --push   Push tags to remote (implies --apply)"
      exit 0
      ;;
  esac
done

if [ "$PUSH" = true ]; then
  APPLY=true
fi

# Ensure we're in the repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ -z "$REPO_ROOT" ]; then
  echo "❌ Not in a git repository"
  exit 1
fi
cd "$REPO_ROOT"

VERSION="v1.0.0"
CREATED=0
SKIPPED=0
TOTAL=0
TAGS_TO_PUSH=()

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BULK MODULE TAGGER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ "$APPLY" = false ]; then
  echo "🔍 DRY RUN MODE — no tags will be created"
  echo "   Run with --apply to create tags"
  echo ""
fi

for PROVIDER_DIR in aws azurerm gcp; do
  if [ ! -d "$PROVIDER_DIR" ]; then
    echo "⚠️  Directory not found: $PROVIDER_DIR — skipping"
    continue
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📂 Processing: $PROVIDER_DIR/"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  DIR_COUNT=0
  for MODULE_DIR in "$PROVIDER_DIR"/*/; do
    # Strip trailing slash to get directory name
    MODULE_DIR="${MODULE_DIR%/}"
    MODULE_NAME="$(basename "$MODULE_DIR")"
    TAG_NAME="${MODULE_NAME}-${VERSION}"

    TOTAL=$((TOTAL + 1))
    DIR_COUNT=$((DIR_COUNT + 1))

    # Check if tag already exists
    if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
      echo "   ⏭  $TAG_NAME (already exists)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    if [ "$APPLY" = true ]; then
      git tag "$TAG_NAME"
      echo "   ✅ $TAG_NAME"
      TAGS_TO_PUSH+=("$TAG_NAME")
    else
      echo "   🔍 $TAG_NAME (would create)"
    fi
    CREATED=$((CREATED + 1))
  done

  echo "   → $DIR_COUNT modules in $PROVIDER_DIR/"
  echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Total modules:   $TOTAL"
echo "   Tags to create:  $CREATED"
echo "   Already tagged:  $SKIPPED"
if [ "$APPLY" = false ]; then
  echo "   Mode:            DRY RUN"
  echo ""
  echo "👉 Run with --apply to create tags locally"
  echo "👉 Run with --apply --push to create and push tags"
else
  echo "   Mode:            APPLIED"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Push if requested
if [ "$PUSH" = true ] && [ ${#TAGS_TO_PUSH[@]} -gt 0 ]; then
  echo ""
  echo "📤 Pushing ${#TAGS_TO_PUSH[@]} tags to origin..."
  git push origin "${TAGS_TO_PUSH[@]}"
  echo "✅ All tags pushed"
elif [ "$PUSH" = true ] && [ ${#TAGS_TO_PUSH[@]} -eq 0 ]; then
  echo ""
  echo "ℹ️  No new tags to push"
fi
