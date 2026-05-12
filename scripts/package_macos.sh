#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FlowLog"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_DIR="$REPO_ROOT/client"
BUILD_APP="$CLIENT_DIR/build/macos/Build/Products/Release/$APP_NAME.app"
INSTALL_DIR="/Applications"
DO_BUILD=1
DO_OPEN=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Build the macOS release app and install it locally.

Options:
  --install-dir DIR   Install target directory. Default: /Applications
  --no-build          Skip flutter build and install the existing release app
  --open              Open the app after installation
  -h, --help          Show this help

Examples:
  scripts/package_macos.sh
  scripts/package_macos.sh --open
  scripts/package_macos.sh --install-dir "$HOME/Applications"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --install-dir" >&2
        exit 2
      fi
      INSTALL_DIR="$2"
      shift 2
      ;;
    --no-build)
      DO_BUILD=0
      shift
      ;;
    --open)
      DO_OPEN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$CLIENT_DIR" ]]; then
  echo "Flutter client directory not found: $CLIENT_DIR" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter command not found. Make sure Flutter is installed and on PATH." >&2
  exit 1
fi

if [[ "$DO_BUILD" -eq 1 ]]; then
  echo "Building macOS release app..."
  (cd "$CLIENT_DIR" && flutter build macos)
fi

if [[ ! -d "$BUILD_APP" ]]; then
  echo "Built app not found: $BUILD_APP" >&2
  echo "Run without --no-build first, or check the Flutter build output." >&2
  exit 1
fi

INSTALL_APP="$INSTALL_DIR/$APP_NAME.app"
NEEDS_SUDO=0
if [[ "$INSTALL_DIR" == "/Applications" || ! -w "$INSTALL_DIR" ]]; then
  NEEDS_SUDO=1
fi

echo "Installing to $INSTALL_APP..."
if [[ "$NEEDS_SUDO" -eq 1 ]]; then
  sudo -v
  sudo mkdir -p "$INSTALL_DIR"
  sudo rm -rf "$INSTALL_APP"
  sudo ditto "$BUILD_APP" "$INSTALL_APP"
  sudo xattr -dr com.apple.quarantine "$INSTALL_APP" 2>/dev/null || true
else
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_APP"
  ditto "$BUILD_APP" "$INSTALL_APP"
  xattr -dr com.apple.quarantine "$INSTALL_APP" 2>/dev/null || true
fi

echo "Installed: $INSTALL_APP"

if [[ "$DO_OPEN" -eq 1 ]]; then
  open "$INSTALL_APP"
fi
