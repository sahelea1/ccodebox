# syntax=docker/dockerfile:1.6
#
# ccodebox / docker-web (merged variant)
#
# A single self-contained image that runs the OpenCode web UI AND ships the
# official Claude Code CLI plus the Continuous Claude v3 + continuous-code
# agent-orchestration projects pre-installed, so both the "continuous claude"
# and "continuous code" workflows are available out of the box.
#
# State (sessions, history, opencode data, claude config, auth, project files)
# is written under /data, which is bind-mounted to a named docker volume in
# docker-compose.yml. That is the only thing that needs to persist.

FROM node:20-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/root/.bun/bin:/root/.opencode/bin:/root/.local/bin:${PATH}" \
    # Track the continuous-code `dev` branch. Rebuilds pick up whatever is at
    # the tip of `dev` at build time; use `docker compose build --no-cache` (or
    # bust the layer some other way) to force a fresh checkout.
    CONTINUOUS_CODE_REPO="https://github.com/sahelea1/continuous-code.git" \
    CONTINUOUS_CODE_REF="dev" \
    # Pin the opencode CLI version so rebuilds are reproducible and we don't
    # depend on api.github.com being reachable / unrate-limited at build time.
    OPENCODE_VERSION="1.14.50" \
    # Pin the Continuous Claude v3 revision so rebuilds are reproducible.
    CONTINUOUS_CLAUDE_REPO_URL="https://github.com/parcadei/Continuous-Claude-v3.git" \
    CONTINUOUS_CLAUDE_REF="d07ff4b06b62f43771bc0c927d0211b734d6149e" \
    # Claude Code config lives under /data so it survives container recreation.
    CLAUDE_CONFIG_DIR=/data/claude/config \
    CLAUDE_CODE_SUBAGENT_MODEL=sonnet \
    CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=120000 \
    CONTINUOUS_CLAUDE_REPO="/opt/continuous-claude"

# System deps. tini gives clean PID 1 signal handling so `docker stop` is fast.
# python3 + uv are needed by the Continuous Claude wizard. tmux/vim/less/rg are
# handy when exec'ing into the container interactively. openssh-client is used
# by git-over-ssh and by Continuous Claude tooling.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      jq \
      less \
      openssh-client \
      python3 \
      python3-pip \
      python3-venv \
      ripgrep \
      tini \
      tmux \
      unzip \
      vim \
 && rm -rf /var/lib/apt/lists/*

# Optional: if the build context contains a `.extra-ca.crt` file (e.g. you are
# behind a TLS-intercepting corporate / sandbox proxy), trust it. Gitignored
# by default. Skipped silently if the file is absent.
COPY .extra-ca.cr[t] /usr/local/share/ca-certificates/extra-ca.crt
RUN if [ -s /usr/local/share/ca-certificates/extra-ca.crt ]; then \
      update-ca-certificates ; \
      # Make the system CA bundle visible to Node/Bun/npm too.
      echo "NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt" >> /etc/environment ; \
    else \
      rm -f /usr/local/share/ca-certificates/extra-ca.crt ; \
    fi
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# Bun (fast install for the continuous-code plugin) + OpenCode (pinned) +
# Claude Code CLI (official, global npm) + uv (Astral, for Continuous Claude
# wizard).
RUN curl -fsSL https://bun.sh/install | bash \
 && curl -fsSL https://opencode.ai/install | bash -s -- --version "${OPENCODE_VERSION}" \
 && npm install -g @anthropic-ai/claude-code \
 && curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Bring in the continuous-code project. Default path: git clone at pinned SHA.
# Fallback: if a `.continuous-code-snapshot/` directory exists in the build
# context (gitignored, useful behind private-repo / offline builds), use it
# instead. Both paths produce the same end state under /opt/continuous-code.
#
# `COPY` with an optional glob (the `[t]` in the path) lets the build succeed
# whether the snapshot is present or not — when absent, nothing is copied.
COPY .continuous-code-snapsho[t] /opt/continuous-code-snapshot/
RUN set -e ; \
    if [ -d /opt/continuous-code-snapshot ] && [ -n "$(ls -A /opt/continuous-code-snapshot 2>/dev/null)" ]; then \
      echo "Using pre-staged continuous-code snapshot from build context" ; \
      mv /opt/continuous-code-snapshot /opt/continuous-code ; \
    else \
      echo "Cloning ${CONTINUOUS_CODE_REPO} at ${CONTINUOUS_CODE_REF}" ; \
      rm -rf /opt/continuous-code-snapshot ; \
      git clone "${CONTINUOUS_CODE_REPO}" /opt/continuous-code ; \
      git -C /opt/continuous-code checkout "${CONTINUOUS_CODE_REF}" ; \
    fi ; \
    cd /opt/continuous-code ; \
    bun install ; \
    npx tsc ; \
    mkdir -p /opt/opencode-config/agents /opt/opencode-config/commands ; \
    cp agents/*.md /opt/opencode-config/agents/ ; \
    cp commands/*.md /opt/opencode-config/commands/ ; \
    printf '{"dependencies":{}}\n' > /opt/opencode-config/package.json ; \
    (cd /opt/opencode-config && npm install file:///opt/continuous-code --save) ; \
    cp /opt/continuous-code/opencode.json /opt/opencode-config/opencode.json

# Patch orchestrator agent files to prevent recursive spawning of orchestrators
RUN for f in /opt/opencode-config/agents/*.md; do \
      [ -f "$f" ] || continue ; \
      fname=$(basename "$f") ; \
      name_line=$(grep -i '^name:' "$f" 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]' || true) ; \
      if echo "$fname $name_line" | grep -qi 'orchestrator'; then \
        echo "Patching orchestrator agent: $f" ; \
        printf '\n\n**CRITICAL ORCHESTRATOR RULE**: YOU yourself ARE the orchestrator. You are NOT ALLOWED TO SPAWN OTHER ORCHESTRATOR NODES. Only spawn subagents of a DIFFERENT type. NEVER spawn another orchestrator agent under any circumstances.\n' >> "$f" ; \
      fi ; \
    done

# Bring in Continuous Claude v3 (the parcadei/Continuous-Claude-v3 project)
# pinned to a specific SHA. This is the python/uv-based "continuous claude"
# wizard counterpart; it complements the Claude Code CLI.
RUN echo "Cloning ${CONTINUOUS_CLAUDE_REPO_URL} at ${CONTINUOUS_CLAUDE_REF}" \
 && git clone "${CONTINUOUS_CLAUDE_REPO_URL}" /opt/continuous-claude \
 && git -C /opt/continuous-claude checkout "${CONTINUOUS_CLAUDE_REF}"

# Small helper scripts so users can `docker exec -it ccodebox cc-setup` etc.
# Source files live in ./helpers in the build context.
COPY helpers/cc-setup helpers/cc-update helpers/cc-uninstall /usr/local/bin/
RUN chmod +x /usr/local/bin/cc-setup /usr/local/bin/cc-update /usr/local/bin/cc-uninstall

# Pre-seed a couple of convenience aliases for interactive shells.
RUN printf '%s\n' \
      "# ccodebox interactive aliases" \
      "alias claude-opus='CLAUDE_CODE_SUBAGENT_MODEL=sonnet claude --model opus'" \
      >> /root/.bashrc

# Entrypoint: sync persistent dirs, launch opencode web on 0.0.0.0:7878.
COPY entrypoint.sh /usr/local/bin/ccodebox-entrypoint
RUN chmod +x /usr/local/bin/ccodebox-entrypoint

# /data is the only persistent location. docker-compose mounts a named volume
# here. Subdirectories:
#   /data/workspace        -> user's project files; opencode runs against this
#   /data/opencode-config  -> ~/.config/opencode  (agents, commands, plugin)
#   /data/opencode-share   -> ~/.local/share/opencode (sessions, auth, history)
#   /data/claude/config    -> ~/.claude            (Claude Code settings, etc.)
#   /data/claude/claude.json -> ~/.claude.json     (Claude Code auth/state)
#   /data/thoughts         -> continuous-code handoffs & ledgers
RUN mkdir -p /data

EXPOSE 7878

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/ccodebox-entrypoint"]
