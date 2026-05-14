# syntax=docker/dockerfile:1.6
#
# ccodebox / detached-persistent
#
# A single self-contained image that runs the OpenCode web UI and ships with
# the sahelea1/continuous-code agent-orchestration project pre-installed, so
# the "continuous claude" workflow is available out of the box.
#
# State (sessions, history, opencode data, auth, project files) is written
# under /data, which is bind-mounted to a named docker volume in
# docker-compose.yml. That is the only thing that needs to persist.

FROM node:20-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/root/.bun/bin:/root/.opencode/bin:${PATH}" \
    # Pin the continuous-code revision so rebuilds are reproducible.
    CONTINUOUS_CODE_REPO="https://github.com/sahelea1/continuous-code.git" \
    CONTINUOUS_CODE_REF="daa00c3eec83d9e91de6bc05701e901371956266" \
    # Pin the opencode CLI version so rebuilds are reproducible and we don't
    # depend on api.github.com being reachable / unrate-limited at build time.
    OPENCODE_VERSION="1.14.50"

# System deps. tini gives clean PID 1 signal handling so `docker stop` is fast.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      jq \
      tini \
      unzip \
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

# Bun (fast install for the continuous-code plugin) + OpenCode (pinned).
RUN curl -fsSL https://bun.sh/install | bash \
 && curl -fsSL https://opencode.ai/install | bash -s -- --version "${OPENCODE_VERSION}"

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

# Entrypoint: sync persistent dirs, launch opencode web on 0.0.0.0:7878.
COPY entrypoint.sh /usr/local/bin/ccodebox-entrypoint
RUN chmod +x /usr/local/bin/ccodebox-entrypoint

# /data is the only persistent location. docker-compose mounts a named volume
# here. Subdirectories:
#   /data/workspace        -> user's project files; opencode runs against this
#   /data/opencode-config  -> ~/.config/opencode  (agents, commands, plugin)
#   /data/opencode-share   -> ~/.local/share/opencode (sessions, auth, history)
#   /data/thoughts         -> continuous-code handoffs & ledgers
RUN mkdir -p /data

EXPOSE 7878

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/ccodebox-entrypoint"]
