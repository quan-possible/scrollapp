#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
FIXTURE_PATH="$REPO_ROOT/manual/autoscroll-fixture.html"
FIXTURE_URL="file://$FIXTURE_PATH"
DO_OPEN=1

usage() {
  cat <<EOF
Usage: ./scripts/open_autoscroll_fixture.sh [--no-open] [--print-path]

Opens the manual autoscroll verification fixture bundled with this repository.
The fixture is a static HTML page with:
  - plain body scroll
  - nested scroll container
  - horizontal overflow strip
  - link, button, and text-field targets

Options:
  --no-open     Print the fixture path and URL without opening a browser
  --print-path  Same as --no-open
  -h, --help    Show this help text
EOF
}

print_manual_fallback() {
  cat <<EOF
Browser auto-open did not succeed.

Open the fixture manually with either:
  File path: $FIXTURE_PATH
  URL:       $FIXTURE_URL
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-open|--print-path)
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

if [[ ! -f "$FIXTURE_PATH" ]]; then
  echo "Fixture not found: $FIXTURE_PATH" >&2
  exit 1
fi

echo "$FIXTURE_PATH"
echo "$FIXTURE_URL"

if [[ ${DO_OPEN} -eq 1 ]]; then
  if ! open "$FIXTURE_PATH"; then
    print_manual_fallback
  fi
fi
