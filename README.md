# ccodebox

One-container coding sandbox with web UI (OpenCode) and Claude Code CLI, both
pre-wired with the Continuous Claude / Continuous Code agent workflows.

## What's inside

- **OpenCode web UI** on port `7878` with the
  [continuous-code](https://github.com/sahelea1/continuous-code) agents,
  commands, and plugin pre-loaded.
- **Claude Code CLI** (`@anthropic-ai/claude-code`) installed globally and
  ready to run via `docker exec -it ccodebox claude`.
- **Continuous Claude v3** (parcadei/Continuous-Claude-v3) pre-cloned at
  `/opt/continuous-claude`. The file portion of the integration — 32
  agents, 100+ skills, 30 hooks, rules, MCP server wrappers, and
  scripts — is **auto-seeded into `~/.claude` on first launch**, so
  Claude Code has the full CC v3 skill/agent set without any manual
  setup. The interactive `cc-setup` wizard is still available for
  optional extras (Postgres-backed memory store, math packages, Loogle
  theorem search).
- **Python + uv** toolchain so the Continuous Claude wizard and the
  auto-installed Python hooks work out of the box.
- State persisted to a named docker volume (`ccodebox_data`) — survives
  `docker compose down`. Only `docker compose down -v` wipes it.

## Quick start

```bash
cp .env.example .env
# Edit .env: paste your OLLAMA_API_KEY and (optionally) ANTHROPIC_API_KEY
docker compose up -d --build
open http://localhost:7878
```

On the first run the entrypoint:

1. Creates `/data/{workspace,opencode-config,opencode-share,claude/config}`.
2. Seeds the opencode config with the continuous-code agents/commands.
3. Symlinks `~/.claude` and `~/.claude.json` into `/data/claude/`.
4. Seeds `~/.claude` with the Continuous Claude v3 integration baked
   into `/opt/claude-stage` (agents, skills, hooks, rules, scripts,
   `settings.json`). Marker file: `~/.claude/.ccodebox-cc-seeded`.
5. Merges `permissions.defaultMode = "acceptEdits"` into the Claude
   Code `settings.json` so the CLI doesn't prompt for every edit while
   preserving the cc-v3 hooks/statusLine.
6. Launches `opencode web` on `0.0.0.0:7878`.

## Using Claude Code CLI

```bash
docker exec -it ccodebox claude          # default model
docker exec -it ccodebox claude-opus     # alias: --model opus, sonnet subagent
```

If you didn't set `ANTHROPIC_API_KEY` the first invocation will walk you
through interactive login. Credentials persist under
`/data/claude/claude.json`, so they survive `docker compose down` and
container recreation.

## Continuous Claude v3 integration

The CC v3 file integration (32 agents, 100+ skills, 30 lifecycle
hooks, rules, MCP server wrappers, helper scripts, and a wired-up
`settings.json`) is **automatically installed** into `~/.claude` on the
container's first launch from a stage directory baked into the image at
build time (`/opt/claude-stage`). Claude Code can use the full CC v3
skill set on the very first `claude` invocation — no manual `cc-setup`
required.

If you wipe the volume (`docker compose down -v`) or rebuild the
image, the seed runs again. To force a fresh re-seed without wiping
state, delete the marker:

```bash
docker exec -it ccodebox rm /data/claude/config/.ccodebox-cc-seeded
docker compose restart ccodebox
```

The interactive `cc-setup` wizard is still available for optional
extras (Postgres-backed memory store with pgvector, math packages,
Loogle theorem search, embedding-model download). Run it with:

```bash
docker exec -it ccodebox cc-setup
```

Companion helpers:

```bash
docker exec -it ccodebox cc-update       # pull latest, rerun wizard updates
docker exec -it ccodebox cc-uninstall    # remove Continuous Claude config
```

## Persistence model

State lives in a single named Docker volume `ccodebox_data`, mounted at
`/data` inside the container:

| Path inside volume         | What                                                  |
| -------------------------- | ----------------------------------------------------- |
| `workspace/`               | Your project files; opencode runs in here             |
| `opencode-config/`         | `~/.config/opencode` (agents, commands, plugin)       |
| `opencode-share/`          | `~/.local/share/opencode` (sessions, auth, logs)      |
| `claude/config/`           | `~/.claude` (Claude Code settings + history)          |
| `claude/claude.json`       | `~/.claude.json` (Claude Code auth token)             |
| `workspace/thoughts/`      | continuous-code handoffs and continuity ledgers       |

### Lifecycle

| Command                          | Container | Volume `ccodebox_data` |
| -------------------------------- | --------- | ---------------------- |
| `docker compose stop`            | stopped   | kept                   |
| `docker compose start`           | running   | kept                   |
| `docker compose down`            | removed   | **kept**               |
| `docker compose up -d`           | created   | reused                 |
| `docker compose down -v`         | removed   | **wiped**              |
| `docker volume rm ccodebox_data` | —         | **wiped**              |

To wipe everything and start fresh:

```bash
docker compose down -v
docker compose up -d --build
```

## Env vars

| Env var (in `.env`)   | Purpose                                                    |
| --------------------- | ---------------------------------------------------------- |
| `OLLAMA_API_KEY`      | Auth for the default Ollama Cloud models in OpenCode       |
| `ANTHROPIC_API_KEY`   | Auth for the Claude Code CLI (optional, falls back to `claude login`) |
| `PORT`                | Host port the web UI is published on (default `7878`)      |

To use a different LLM provider in OpenCode, edit
`/data/workspace/opencode.json` from the web UI's file browser. See
<https://opencode.ai/docs/providers/>.

## Day-to-day

```bash
docker compose up -d --build      # rebuild + run
docker compose logs -f ccodebox   # tail logs
docker compose stop               # pause, keep state
docker compose start              # resume
docker compose down               # remove container, keep state
docker compose down -v            # nuke everything
```

## Layout

```
.
├── Dockerfile           # node + bun + opencode + claude-code + uv + cc-v3
├── docker-compose.yml   # one service, one named volume, port 7878
├── entrypoint.sh        # seeds /data, wires Claude config, launches opencode
├── .env.example         # OLLAMA_API_KEY=, ANTHROPIC_API_KEY=
├── .gitignore
└── README.md
```

## Troubleshooting

**Build fails on TLS / certificate errors (corporate proxy).** Drop your
intercepting CA's PEM into `.extra-ca.crt` in the repo root and rebuild.
The Dockerfile picks it up via a conditional `COPY` and updates the
system CA bundle; `.extra-ca.crt` is gitignored.

**Continuous Claude wizard fails on first run.** The wizard expects a
TTY. Always run `cc-setup` with `docker exec -it` (interactive +
TTY), not in a non-interactive script.

**Web UI shows "model unauthorized".** Make sure `OLLAMA_API_KEY` (or
the credentials for whichever provider you switched to in
`opencode.json`) is set in `.env`, then `docker compose up -d` to
recreate the container.

## License

MIT.
