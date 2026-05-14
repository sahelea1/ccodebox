#!/usr/bin/env bash
# ccodebox entrypoint.
#
# Wires the persistent /data volume to the locations opencode and
# continuous-code expect, then launches the opencode web UI bound to
# 0.0.0.0:7878 so it is reachable from the host.

set -euo pipefail

DATA_ROOT="${CCODEBOX_DATA_ROOT:-/data}"
WORKSPACE_DIR="$DATA_ROOT/workspace"
OPENCODE_CONFIG_DIR="$DATA_ROOT/opencode-config"
OPENCODE_SHARE_DIR="$DATA_ROOT/opencode-share"
THOUGHTS_DIR="$WORKSPACE_DIR/thoughts"

PORT="${OPENCODE_PORT:-7878}"
HOSTNAME="${OPENCODE_HOSTNAME:-0.0.0.0}"

mkdir -p \
  "$WORKSPACE_DIR" \
  "$OPENCODE_CONFIG_DIR" \
  "$OPENCODE_SHARE_DIR" \
  "$THOUGHTS_DIR/shared/handoffs" \
  "$THOUGHTS_DIR/ledgers"

# First-time-setup: seed the persistent opencode config with the
# continuous-code agents, commands, plugin, and opencode.json baked into
# the image. After this seed any user edits live in the volume and
# survive image rebuilds.
if [ ! -f "$OPENCODE_CONFIG_DIR/.seeded" ]; then
  echo "[ccodebox] seeding $OPENCODE_CONFIG_DIR with continuous-code defaults"
  cp -a /opt/opencode-config/. "$OPENCODE_CONFIG_DIR/"
  touch "$OPENCODE_CONFIG_DIR/.seeded"
fi

# Seed a workspace opencode.json so the user has a sensible default project
# config wired to the continuous-code agents on first launch.
if [ ! -f "$WORKSPACE_DIR/opencode.json" ]; then
  cp /opt/continuous-code/opencode.json "$WORKSPACE_DIR/opencode.json"
fi

# Opencode requires a git repo inside the working directory. Init one
# silently if the user hasn't already done so.
if [ ! -d "$WORKSPACE_DIR/.git" ]; then
  (
    cd "$WORKSPACE_DIR"
    git init -q
    git config user.email "ccodebox@local"
    git config user.name "ccodebox"
    if [ ! -f README.md ]; then
      echo "# workspace" > README.md
    fi
    git add -A
    git -c commit.gpgsign=false commit -q -m "init workspace" || true
  )
fi

# Symlink the persistent directories to the paths opencode expects in $HOME.
mkdir -p /root/.config /root/.local/share
ln -sfn "$OPENCODE_CONFIG_DIR" /root/.config/opencode
ln -sfn "$OPENCODE_SHARE_DIR"  /root/.local/share/opencode

# Sanity warn if no key was supplied. Don't fail; opencode itself will
# tell the user when they try to send a message.
if [ -z "${OLLAMA_API_KEY:-}" ]; then
  echo "[ccodebox] WARNING: OLLAMA_API_KEY is not set. The web UI will load,"
  echo "[ccodebox]          but Ollama Cloud model calls will fail until you"
  echo "[ccodebox]          add a key to the .env file and recreate the"
  echo "[ccodebox]          container with: docker compose up -d"
fi

cd "$WORKSPACE_DIR"

echo "[ccodebox] starting opencode web on ${HOSTNAME}:${PORT}"
echo "[ccodebox] workspace: $WORKSPACE_DIR"

# opencode web is the browser UI. --hostname 0.0.0.0 makes it reachable on
# the published port. BROWSER=true skips the automatic browser launch
# attempt (there is no host browser inside the container).
export BROWSER=true
exec opencode web --hostname "$HOSTNAME" --port "$PORT"
