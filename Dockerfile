FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CLAUDE_CONFIG_DIR=/root/.claude
ENV CLAUDE_CODE_SUBAGENT_MODEL=sonnet
ENV CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=120000
ENV PATH="/root/.opencode/bin:/root/.local/bin:${PATH}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      gnupg \
      jq \
      less \
      openssh-client \
      python3 \
      python3-pip \
      ripgrep \
      tmux \
      vim \
      xz-utils \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      docker-ce-cli \
      docker-compose-plugin \
 && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g @anthropic-ai/claude-code \
 && curl -fsSL https://opencode.ai/install | bash \
 && curl -LsSf https://astral.sh/uv/install.sh | sh \
 && git config --system url."https://github.com/".insteadOf "git@github.com:" \
 && git config --system url."https://github.com/".insteadOf "ssh://git@github.com/" \
 && rm -rf /var/lib/apt/lists/*

RUN cat > /usr/local/bin/vibecoding-entrypoint <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="/root/.claude"
CLAUDE_JSON="/root/.claude.json"

CC_REPO="${CONTINUOUS_CLAUDE_REPO:-/root/continuous-claude}"
CC_MARKER="$CLAUDE_DIR/.continuous_claude_enabled"

mkdir -p "$CLAUDE_DIR"
touch "$CLAUDE_JSON"

# Keep GitHub clones/submodules on HTTPS, not SSH.
git config --global url."https://github.com/".insteadOf "git@github.com:" >/dev/null 2>&1 || true
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" >/dev/null 2>&1 || true

# Convenience aliases for interactive shell.
if ! grep -q "alias claude-opus=" /root/.bashrc 2>/dev/null; then
  cat >> /root/.bashrc <<'BASHRC'

alias claude-opus='CLAUDE_CODE_SUBAGENT_MODEL=sonnet claude --model opus'
alias cc-setup='cd "$CONTINUOUS_CLAUDE_REPO/opc" && uv run python -m scripts.setup.wizard'
alias cc-update='cd "$CONTINUOUS_CLAUDE_REPO/opc" && uv run python -m scripts.setup.update'
alias cc-uninstall='cd "$CONTINUOUS_CLAUDE_REPO/opc" && uv run python -m scripts.setup.wizard --uninstall'
BASHRC
fi

echo
echo "Vibecoding container ready."
echo "Workspace: /workspace"
echo
echo "Claude config is persistent:"
echo "  $CLAUDE_DIR"
echo "  $CLAUDE_JSON"
echo
echo "Continuous Claude repo:"
echo "  $CC_REPO"
echo
echo "Model defaults:"
echo "  Main process: start with 'claude-opus' for Opus"
echo "  Subagents:    sonnet via CLAUDE_CODE_SUBAGENT_MODEL=sonnet"
echo

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude command not found."
  exec /bin/bash
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: uv command not found."
  exec /bin/bash
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker CLI not found."
  exec /bin/bash
fi

if [ ! -S /var/run/docker.sock ]; then
  echo "WARNING: /var/run/docker.sock is not mounted."
  echo "Continuous Claude setup needs Docker for PostgreSQL."
  echo "Fix: make sure Docker is running on the host and start with the provided start.sh."
  echo
fi

if [ ! -d "$CC_REPO/.git" ]; then
  echo "Cloning Continuous Claude via HTTPS..."
  mkdir -p "$(dirname "$CC_REPO")"
  git clone https://github.com/parcadei/Continuous-Claude-v3.git "$CC_REPO"
else
  echo "Continuous Claude repo already exists."
fi

if [ ! -f "$CC_MARKER" ]; then
  echo
  echo "Continuous Claude v3 is a community project, not official Anthropic."
  echo "It will install hooks/skills/agents into your persistent ~/.claude config."
  echo
  read -r -p "Run Continuous Claude setup wizard now? [y/N] " answer || answer=""

  case "$answer" in
    y|Y|yes|YES|Yes)
      echo
      echo "Running Continuous Claude setup wizard..."
      echo "Directory: $CC_REPO/opc"
      echo
      cd "$CC_REPO/opc"
      uv run python -m scripts.setup.wizard
      touch "$CC_MARKER"
      echo
      echo "Continuous Claude setup finished."
      echo "Start Claude with: claude-opus"
      echo "Try inside Claude: /workflow"
      ;;
    *)
      echo "Skipping Continuous Claude setup."
      echo
      echo "You can run it later with:"
      echo "  cc-setup"
      ;;
  esac
else
  echo "Continuous Claude already enabled."
  echo "Update later with: cc-update"
  echo "Uninstall with:  cc-uninstall"
fi

echo
exec /bin/bash
EOF

RUN chmod +x /usr/local/bin/vibecoding-entrypoint

WORKDIR /workspace

CMD ["/usr/local/bin/vibecoding-entrypoint"]
