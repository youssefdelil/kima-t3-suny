#!/usr/bin/env bash
# install.sh — Standalone installer for delileche youcef
set -euo pipefail

REPO="https://github.com/youcef/delileche-youcef"
INSTALL_DIR="$HOME/.delileche"
BIN_DIR="/usr/local/bin"

printf "Installing delileche — macOS Cleanup Tool by youcef...\n\n"

# Check macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
  printf "Error: delileche only supports macOS.\n" >&2
  exit 1
fi

# Check for git
if ! command -v git &>/dev/null; then
  printf "Error: git is required to install delileche.\n" >&2
  exit 1
fi

# Clone or update
if [[ -d "${INSTALL_DIR}/.git" ]]; then
  printf "Updating existing installation...\n"
  git -C "$INSTALL_DIR" pull --quiet
else
  printf "Cloning repository to %s...\n" "$INSTALL_DIR"
  git clone --quiet "$REPO" "$INSTALL_DIR"
fi

# Make executable
chmod +x "${INSTALL_DIR}/bin/delileche"

# Symlink — fall back to ~/.local/bin if /usr/local/bin is not writable
if [[ -w "$BIN_DIR" ]]; then
  ln -sf "${INSTALL_DIR}/bin/delileche" "${BIN_DIR}/delileche"
  printf "\n✔ Symlinked to %s/delileche\n" "$BIN_DIR"
else
  LOCAL_BIN="$HOME/.local/bin"
  mkdir -p "$LOCAL_BIN"
  ln -sf "${INSTALL_DIR}/bin/delileche" "${LOCAL_BIN}/delileche"
  printf "\n✔ Symlinked to %s/delileche\n" "$LOCAL_BIN"
  printf "  Add %s to your PATH if not already there:\n" "$LOCAL_BIN"
  printf '  export PATH="%s:$PATH"\n\n' "$LOCAL_BIN"
fi

# Read version from core.sh
VERSION="$(grep '^VERSION=' "${INSTALL_DIR}/lib/core/core.sh" | head -1 | cut -d'"' -f2)"
printf "\n✔ delileche v%s installed successfully!\n" "$VERSION"
printf "  Run: delileche --help\n\n"
