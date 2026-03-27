#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LOCAL_ROOT=${SCROLLAPP_XCODE_LOCAL_DIR:-"$HOME/tmp/scrollapp-xcode"}
PROJECT_NAME="Scrollapp.xcodeproj"
LOCAL_PROJECT="$LOCAL_ROOT/$PROJECT_NAME"

DO_OPEN=1
DO_CHECK=0

usage() {
  cat <<'EOF'
Usage: ./scripts/open_local_xcode.sh [--check] [--no-open] [--print-path]

Prepares a local Xcode wrapper outside Google Drive / File Provider so Xcode
can open the project without freezing on the cloud-backed .xcodeproj.

The wrapper keeps the real source of truth in the original repository by
symlinking the source directories back to the current repo. If `xcodegen` is
installed, the local wrapper regenerates `Scrollapp.xcodeproj` from the real
`project.yml`; otherwise it copies the checked-in project bundle.

Options:
  --check       Run `xcodebuild -list` against the local wrapper after syncing
  --no-open     Prepare the wrapper but do not launch Xcode
  --print-path  Prepare the wrapper, print the local project path, and exit
  -h, --help    Show this help text
EOF
}

print_manual_fallback() {
  cat <<EOF
Auto-open did not succeed.

Open the generated local project manually from Xcode:
  1. Launch Xcode
  2. Choose File > Open...
  3. Open: $LOCAL_PROJECT

Tip: to place the wrapper in a known-local path, rerun with:
  SCROLLAPP_XCODE_LOCAL_DIR=/private/tmp/scrollapp-xcode ./scripts/open_local_xcode.sh --check --no-open
EOF
}

prepare_local_wrapper() {
  mkdir -p "$LOCAL_ROOT"

  rm -rf \
    "$LOCAL_ROOT/Scrollapp" \
    "$LOCAL_ROOT/ScrollappTests" \
    "$LOCAL_PROJECT" \
    "$LOCAL_ROOT/project.yml"

  ln -s "$REPO_ROOT/Scrollapp" "$LOCAL_ROOT/Scrollapp"
  ln -s "$REPO_ROOT/ScrollappTests" "$LOCAL_ROOT/ScrollappTests"

  if command -v xcodegen >/dev/null 2>&1; then
    cp "$REPO_ROOT/project.yml" "$LOCAL_ROOT/project.yml"
    (
      cd "$LOCAL_ROOT"
      xcodegen generate --spec "$LOCAL_ROOT/project.yml"
    )
    rm -f "$LOCAL_ROOT/project.yml"
  else
    cp -R "$REPO_ROOT/$PROJECT_NAME" "$LOCAL_PROJECT"
  fi

  ln -s "$REPO_ROOT/project.yml" "$LOCAL_ROOT/project.yml"
  /usr/bin/xattr -cr "$LOCAL_PROJECT" 2>/dev/null || true
}

run_check() {
  xcodebuild -list -project "$LOCAL_PROJECT"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      DO_CHECK=1
      ;;
    --no-open)
      DO_OPEN=0
      ;;
    --print-path)
      DO_OPEN=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

prepare_local_wrapper

if [[ ${DO_CHECK} -eq 1 ]]; then
  run_check
fi

echo "$LOCAL_PROJECT"

if [[ ${DO_OPEN} -eq 1 ]]; then
  if ! open -a /Applications/Xcode.app "$LOCAL_PROJECT"; then
    print_manual_fallback
  fi
fi
