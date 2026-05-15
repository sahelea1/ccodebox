#!/usr/bin/env bash
# ccodebox entrypoint (docker-web merged variant).
#
# Wires the persistent /data volume to the locations opencode and Claude Code
# expect, then launches the opencode web UI bound to 0.0.0.0:7878 so it is
# reachable from the host. The Claude Code CLI is available alongside, run via
# `docker exec -it ccodebox claude`.

set -euo pipefail

DATA_ROOT="${CCODEBOX_DATA_ROOT:-/data}"
WORKSPACE_DIR="$DATA_ROOT/workspace"
OPENCODE_CONFIG_DIR="$DATA_ROOT/opencode-config"
OPENCODE_SHARE_DIR="$DATA_ROOT/opencode-share"
CLAUDE_CONFIG_HOST="$DATA_ROOT/claude/config"
CLAUDE_JSON_HOST="$DATA_ROOT/claude/claude.json"
THOUGHTS_DIR="$WORKSPACE_DIR/thoughts"

PORT="${OPENCODE_PORT:-7878}"
HOSTNAME="${OPENCODE_HOSTNAME:-0.0.0.0}"

mkdir -p \
  "$WORKSPACE_DIR" \
  "$OPENCODE_CONFIG_DIR" \
  "$OPENCODE_SHARE_DIR" \
  "$CLAUDE_CONFIG_HOST" \
  "$THOUGHTS_DIR/shared/handoffs" \
  "$THOUGHTS_DIR/ledgers"

touch "$CLAUDE_JSON_HOST"

# First-time-setup: seed the persistent opencode config with the
# continuous-code agents, commands, plugin, and opencode.json baked into
# the image. After this seed any user edits live in the volume and
# survive image rebuilds.
if [ ! -f "$OPENCODE_CONFIG_DIR/.seeded" ]; then
  echo "[ccodebox] seeding $OPENCODE_CONFIG_DIR with continuous-code defaults"
  cp -a /opt/opencode-config/. "$OPENCODE_CONFIG_DIR/"
  touch "$OPENCODE_CONFIG_DIR/.seeded"
fi

# Patch orchestrator agents to prevent recursive spawning (idempotent).
# Runs every startup so already-seeded volumes get the fix too.
for _f in "$OPENCODE_CONFIG_DIR/agents/"*.md; do
  [ -f "$_f" ] || continue
  _fname=$(basename "$_f")
  _name_line=$(grep -i '^name:' "$_f" 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]' || true)
  if echo "$_fname $_name_line" | grep -qi 'orchestrator'; then
    if ! grep -q 'NOT ALLOWED TO SPAWN OTHER ORCHESTRATOR' "$_f"; then
      echo "[ccodebox] patching orchestrator agent: $_fname"
      printf '\n\n**CRITICAL ORCHESTRATOR RULE**: YOU yourself ARE the orchestrator. You are NOT ALLOWED TO SPAWN OTHER ORCHESTRATOR NODES. Only spawn subagents of a DIFFERENT type. NEVER spawn another orchestrator agent under any circumstances.\n' >> "$_f"
    fi
  fi
done

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

# Symlink the persistent directories to the paths opencode and Claude Code
# expect in $HOME. Using `ln -sfn` is idempotent across container restarts.
mkdir -p /root/.config /root/.local/share
ln -sfn "$OPENCODE_CONFIG_DIR" /root/.config/opencode
ln -sfn "$OPENCODE_SHARE_DIR"  /root/.local/share/opencode
ln -sfn "$CLAUDE_CONFIG_HOST"  /root/.claude
ln -sfn "$CLAUDE_JSON_HOST"    /root/.claude.json

# First-time seed: copy the Continuous Claude v3 integration (agents,
# skills, hooks, rules, scripts, settings.json, MCP server wrappers)
# baked into /opt/claude-stage at build time. This makes the full set of
# CC v3 skills/agents available to `claude` immediately; no manual
# `cc-setup` run is required for the file portion of the integration.
# `cc-setup` is still available for users who additionally want the
# optional Postgres-backed memory store, math packages, Loogle, etc.
CC_STAGE="${CCODEBOX_CLAUDE_STAGE:-/opt/claude-stage}"
CC_SEEDED="$CLAUDE_CONFIG_HOST/.ccodebox-cc-seeded"
if [ -d "$CC_STAGE" ] && [ ! -f "$CC_SEEDED" ]; then
  echo "[ccodebox] seeding $CLAUDE_CONFIG_HOST with Continuous Claude v3 integration"
  for d in agents skills hooks rules servers plugins runtime scripts; do
    if [ -d "$CC_STAGE/$d" ]; then
      mkdir -p "$CLAUDE_CONFIG_HOST/$d"
      cp -an "$CC_STAGE/$d/." "$CLAUDE_CONFIG_HOST/$d/" 2>/dev/null || \
        cp -a  "$CC_STAGE/$d/." "$CLAUDE_CONFIG_HOST/$d/"
    fi
  done
  if [ -f "$CC_STAGE/settings.json" ] && [ ! -s "$CLAUDE_CONFIG_HOST/settings.json" ]; then
    cp "$CC_STAGE/settings.json" "$CLAUDE_CONFIG_HOST/settings.json"
  fi
  printf 'seeded from %s at %s\n' "$CC_STAGE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$CC_SEEDED"
fi

# Inject acceptEdits into the persistent Claude Code settings.json so the
# CLI doesn't prompt for every edit. Uses jq merge so any pre-existing
# user keys (including the cc-v3 hooks / statusLine seeded above) are
# preserved; falls back to a fresh write if jq fails.
CC_SETTINGS="$CLAUDE_CONFIG_HOST/settings.json"
if [ ! -s "$CC_SETTINGS" ]; then printf '{}\n' > "$CC_SETTINGS"; fi
tmp="$(mktemp)"
if jq '.permissions.defaultMode = "acceptEdits"' "$CC_SETTINGS" > "$tmp" 2>/dev/null; then
  mv "$tmp" "$CC_SETTINGS"
else
  rm -f "$tmp"
  printf '%s\n' '{"permissions":{"defaultMode":"acceptEdits"}}' > "$CC_SETTINGS"
fi

# Sanity warn if no key was supplied. Don't fail; opencode itself will
# tell the user when they try to send a message.
if [ -z "${OLLAMA_API_KEY:-}" ]; then
  echo "[ccodebox] WARNING: OLLAMA_API_KEY is not set. The web UI will load,"
  echo "[ccodebox]          but Ollama Cloud model calls will fail until you"
  echo "[ccodebox]          add a key to the .env file and recreate the"
  echo "[ccodebox]          container with: docker compose up -d"
fi

cd "$WORKSPACE_DIR"

cat <<EOF
[ccodebox] ----------------------------------------------------------------
[ccodebox] OpenCode web UI:        http://localhost:${PORT}
[ccodebox] Claude Code CLI:        docker exec -it ccodebox claude
[ccodebox] Claude Code (opus):     docker exec -it ccodebox claude-opus
[ccodebox] CC v3 skills/agents:    pre-installed in ~/.claude (seed marker:
[ccodebox]                         ${CC_SEEDED})
[ccodebox] Optional CC v3 extras:  docker exec -it ccodebox cc-setup
[ccodebox]                         (Postgres-backed memory, math, Loogle)
[ccodebox] Workspace:              ${WORKSPACE_DIR}
[ccodebox] ----------------------------------------------------------------
EOF

echo "[ccodebox] starting opencode web on ${HOSTNAME}:${PORT}"

# opencode web is the browser UI. --hostname 0.0.0.0 makes it reachable on
# the published port. BROWSER=true skips the automatic browser launch
# attempt (there is no host browser inside the container).
export BROWSER=true
exec opencode web --hostname "$HOSTNAME" --port "$PORT"
