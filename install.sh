#!/usr/bin/env bash
# Install/uninstall the ccodebox shell helper and container template.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${HOME}/.local/share/coding-container-template"
BLOCK_BEGIN="# >>> ccodebox >>>"
BLOCK_END="# <<< ccodebox <<<"

usage() {
  cat <<EOF
ccodebox installer

Usage: $(basename "$0") [--uninstall] [--rc <path>]

Install (default):
  - Copies Dockerfile and start.sh into:
      $TEMPLATE_DIR
  - Appends a 'ccodebox' shell function to your shell rc file
    (~/.zshrc or ~/.bashrc, auto-detected from \$SHELL)

Options:
  --uninstall   Remove the ccodebox function and (optionally) the template dir
  --rc <path>   Use a specific rc file instead of auto-detection
  -h, --help    Show this help
EOF
}

log()  { printf '  %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

detect_rc() {
  case "${SHELL:-}" in
    */zsh)  printf '%s\n' "${HOME}/.zshrc"  ;;
    */bash) printf '%s\n' "${HOME}/.bashrc" ;;
    *)
      if   [ -f "${HOME}/.zshrc"  ]; then printf '%s\n' "${HOME}/.zshrc"
      elif [ -f "${HOME}/.bashrc" ]; then printf '%s\n' "${HOME}/.bashrc"
      else printf '%s\n' "${HOME}/.bashrc"
      fi
      ;;
  esac
}

remove_block() {
  local rc="$1"
  [ -f "$rc" ] || return 0
  if ! grep -qF "$BLOCK_BEGIN" "$rc"; then
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "$rc" > "$tmp"
  mv "$tmp" "$rc"
  log "Removed ccodebox block from $rc"
}

check_prereqs() {
  command -v docker    >/dev/null 2>&1 || warn "docker not found in PATH"
  command -v alacritty >/dev/null 2>&1 || warn "alacritty not found in PATH"
}

install_template() {
  log "Copying template files to $TEMPLATE_DIR"
  mkdir -p "$TEMPLATE_DIR"
  install -m 0644 "$SCRIPT_DIR/Dockerfile" "$TEMPLATE_DIR/Dockerfile"
  install -m 0755 "$SCRIPT_DIR/start.sh"   "$TEMPLATE_DIR/start.sh"
}

install_shell_block() {
  local rc="$1"
  log "Updating $rc"
  mkdir -p "$(dirname "$rc")"
  touch "$rc"
  remove_block "$rc"
  cat >> "$rc" <<EOF
$BLOCK_BEGIN
# Spawn a containerized Claude Code workspace for the current directory.
# See: https://github.com/sahelea1/ccodebox
ccodebox() {
  local template_dir="$TEMPLATE_DIR"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl start docker >/dev/null 2>&1 || true
  fi
  mkdir -p ./mount
  cp "\$template_dir/Dockerfile" ./Dockerfile
  cp "\$template_dir/start.sh"   ./start.sh
  chmod +x ./start.sh
  ./start.sh "\$@"
}
$BLOCK_END
EOF
}

do_install() {
  local rc="$1"
  check_prereqs
  install_template
  install_shell_block "$rc"
  cat <<EOF

ccodebox installed.

Next steps:
  1. Reload your shell:   source $rc
  2. cd into a project:   cd ~/code/my-project
  3. Start a session:     ccodebox

Rebuild the image after editing the Dockerfile:
  ccodebox --rebuild
EOF
}

do_uninstall() {
  local rc="$1"
  remove_block "$rc"
  if [ -d "$TEMPLATE_DIR" ]; then
    local answer=""
    read -r -p "Also remove $TEMPLATE_DIR ? [y/N] " answer || true
    case "$answer" in
      y|Y|yes|YES|Yes)
        rm -rf "$TEMPLATE_DIR"
        log "Removed $TEMPLATE_DIR"
        ;;
      *)
        log "Kept $TEMPLATE_DIR"
        ;;
    esac
  fi
  echo
  echo "ccodebox uninstalled."
  echo "Open a new shell to drop the function from the current session."
}

main() {
  local mode="install"
  local rc=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --uninstall|uninstall) mode="uninstall" ;;
      install)               mode="install" ;;
      --rc)                  shift; rc="${1:-}" ;;
      -h|--help)             usage; exit 0 ;;
      *)                     usage; exit 2 ;;
    esac
    shift
  done

  [ -n "$rc" ] || rc="$(detect_rc)"

  case "$mode" in
    install)   do_install   "$rc" ;;
    uninstall) do_uninstall "$rc" ;;
  esac
}

main "$@"
