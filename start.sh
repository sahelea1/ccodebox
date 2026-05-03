#!/usr/bin/env bash
# Build (if needed) and launch the ccodebox container in a new Alacritty window.
set -euo pipefail

IMAGE_NAME="claude-opencode-cli:latest"
TEMPLATE_DIR="$HOME/.local/share/coding-container-template"

PROJECT_DIR="$(pwd)"
MOUNT_DIR="$PROJECT_DIR/mount"

CLAUDE_CONFIG_DIR="$TEMPLATE_DIR/config/claude"
CLAUDE_JSON_FILE="$TEMPLATE_DIR/config/claude.json"

OPENCODE_CONFIG_DIR="$TEMPLATE_DIR/config/opencode"
OPENCODE_DATA_DIR="$TEMPLATE_DIR/config/opencode-data"

CONTINUOUS_CLAUDE_REPO="$TEMPLATE_DIR/continuous-claude"

UV_CACHE_DIR="$TEMPLATE_DIR/config/uv-cache"
UV_DATA_DIR="$TEMPLATE_DIR/config/uv-data"
UV_STATE_DIR="$TEMPLATE_DIR/config/uv-state"
LOCAL_BIN_DIR="$TEMPLATE_DIR/config/local-bin"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--rebuild] [--help]

  --rebuild   Force a rebuild of the Docker image ($IMAGE_NAME).
  --help      Show this message.

The container mounts ./mount as /workspace.
EOF
}

REBUILD=0
case "${1:-}" in
  "")            ;;
  --rebuild)     REBUILD=1 ;;
  -h|--help)     usage; exit 0 ;;
  *)             usage; exit 2 ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "error: 'docker' not found in PATH" >&2
  exit 1
fi

if ! command -v alacritty >/dev/null 2>&1; then
  echo "error: 'alacritty' not found in PATH" >&2
  exit 1
fi

mkdir -p "$MOUNT_DIR"
mkdir -p "$CLAUDE_CONFIG_DIR"
mkdir -p "$OPENCODE_CONFIG_DIR"
mkdir -p "$OPENCODE_DATA_DIR"
mkdir -p "$CONTINUOUS_CLAUDE_REPO"

mkdir -p "$UV_CACHE_DIR"
mkdir -p "$UV_DATA_DIR"
mkdir -p "$UV_STATE_DIR"
mkdir -p "$LOCAL_BIN_DIR"

touch "$CLAUDE_JSON_FILE"

if [ "$REBUILD" -eq 1 ] || ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "Building Docker image: $IMAGE_NAME"
  docker build -t "$IMAGE_NAME" "$PROJECT_DIR"
else
  echo "Using existing Docker image: $IMAGE_NAME"
  echo "Run with --rebuild to rebuild it."
fi

DOCKER_SOCKET_ARGS=""
if [ -S /var/run/docker.sock ]; then
  DOCKER_SOCKET_ARGS="-v /var/run/docker.sock:/var/run/docker.sock"
else
  echo "WARNING: /var/run/docker.sock not found."
  echo "Continuous Claude setup needs host Docker for PostgreSQL."
fi

alacritty \
  --working-directory "$PROJECT_DIR" \
  -e bash -lc "
    docker run --rm -it \
      $DOCKER_SOCKET_ARGS \
      -e CONTINUOUS_CLAUDE_REPO=\"$CONTINUOUS_CLAUDE_REPO\" \
      -e CLAUDE_CODE_SUBAGENT_MODEL=sonnet \
      -e UV_CACHE_DIR=/root/.cache/uv \
      -e UV_TOOL_BIN_DIR=/root/.local/bin \
      -v \"$MOUNT_DIR:/workspace\" \
      -v \"$CLAUDE_CONFIG_DIR:/root/.claude\" \
      -v \"$CLAUDE_JSON_FILE:/root/.claude.json\" \
      -v \"$OPENCODE_CONFIG_DIR:/root/.config/opencode\" \
      -v \"$OPENCODE_DATA_DIR:/root/.local/share/opencode\" \
      -v \"$UV_CACHE_DIR:/root/.cache/uv\" \
      -v \"$UV_DATA_DIR:/root/.local/share/uv\" \
      -v \"$UV_STATE_DIR:/root/.local/state/uv\" \
      -v \"$LOCAL_BIN_DIR:/root/.local/bin\" \
      -v \"$CONTINUOUS_CLAUDE_REPO:$CONTINUOUS_CLAUDE_REPO\" \
      \"$IMAGE_NAME\"
  " &
