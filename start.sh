#!/usr/bin/env bash
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

mkdir -p "$MOUNT_DIR"
mkdir -p "$CLAUDE_CONFIG_DIR"
mkdir -p "$OPENCODE_CONFIG_DIR"
mkdir -p "$OPENCODE_DATA_DIR"
mkdir -p "$CONTINUOUS_CLAUDE_REPO"

touch "$CLAUDE_JSON_FILE"

docker build -t "$IMAGE_NAME" "$PROJECT_DIR"

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
      -v \"$MOUNT_DIR:/workspace\" \
      -v \"$CLAUDE_CONFIG_DIR:/root/.claude\" \
      -v \"$CLAUDE_JSON_FILE:/root/.claude.json\" \
      -v \"$OPENCODE_CONFIG_DIR:/root/.config/opencode\" \
      -v \"$OPENCODE_DATA_DIR:/root/.local/share/opencode\" \
      -v \"$CONTINUOUS_CLAUDE_REPO:$CONTINUOUS_CLAUDE_REPO\" \
      \"$IMAGE_NAME\"
  " &
