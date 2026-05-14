# ccodebox

A one-command, browser-accessible coding agent: [OpenCode](https://opencode.ai)
running inside Docker, pre-wired with the
[continuous-code](https://github.com/sahelea1/continuous-code) agent
orchestration project so the "continuous claude" workflow is ready out of the
box.

```
clone -> docker compose up --build -d -> open http://localhost:7878
```

## Quick start

```bash
git clone https://github.com/sahelea1/ccodebox.git
cd ccodebox
git checkout detached-persistent

cp .env.example .env
# Edit .env and paste your Ollama Cloud API key into OLLAMA_API_KEY=

docker compose up --build -d
```

The web UI is at:

```
http://0.0.0.0:7878
```

(or `http://localhost:7878` from the same machine, or
`http://<host-ip>:7878` from another machine on the LAN).

To change the host port, edit `PORT=` in `.env` and run
`docker compose up -d` again.

## What's inside

- **OpenCode** — the AI coding agent, running in browser/web UI mode.
- **continuous-code** — pinned to commit
  `daa00c3eec83d9e91de6bc05701e901371956266`, cloned and installed at build
  time. The 12-subagent "build / scout / oracle / sleuth / kraken / spark /
  arbiter / judge / plan-agent / phoenix / architect / scribe /
  memory-extractor" pipeline is available immediately, along with the
  `/build`, `/fix`, `/tdd`, `/explore`, `/review`, `/refactor`, `/handoff`,
  `/resume` slash commands.
- Default models are `ollama-cloud/deepseek-v4-pro` and
  `ollama-cloud/deepseek-v4-flash`. Swap them in
  `/data/workspace/opencode.json` (visible from the web UI's file browser).

## Persistence

State lives in a single named Docker volume called `ccodebox_data`, mounted
at `/data` inside the container. It contains:

| Path inside volume   | What                                              |
| -------------------- | ------------------------------------------------- |
| `workspace/`         | Your project files; opencode runs in here         |
| `opencode-config/`   | `~/.config/opencode` (agents, commands, plugin)   |
| `opencode-share/`    | `~/.local/share/opencode` (sessions, auth, logs)  |
| `workspace/thoughts/`| continuous-code handoffs and continuity ledgers   |

### Lifecycle

| Command                         | Container | Volume `ccodebox_data` |
| ------------------------------- | --------- | ---------------------- |
| `docker compose stop`           | stopped   | kept                   |
| `docker compose start`          | running   | kept                   |
| `docker stop ccodebox`          | stopped   | kept                   |
| `docker start ccodebox`         | running   | kept                   |
| `docker compose down`           | removed   | **kept**               |
| `docker compose up -d`          | created   | reused                 |
| `docker compose down -v`        | removed   | **wiped**              |
| `docker volume rm ccodebox_data`| —         | **wiped**              |

So your sessions, history, code, agent config, and handoffs all survive
restarts and even a full `docker compose down`. They are only deleted when
you explicitly pass `-v` (or destroy the volume by name).

## Day-to-day

```bash
# Start (first time or after editing .env / Dockerfile)
docker compose up --build -d

# Tail logs
docker compose logs -f ccodebox

# Pause without losing state
docker compose stop

# Resume
docker compose start

# Remove container, keep state
docker compose down

# Nuke everything
docker compose down -v
```

## Configuration

| Env var (in `.env`)   | Purpose                                       |
| --------------------- | --------------------------------------------- |
| `OLLAMA_API_KEY`      | Auth for the default Ollama Cloud models      |
| `PORT`                | Host port for the web UI (default `7878`)     |

To use a different LLM provider (Anthropic, OpenAI, ...), edit
`/data/workspace/opencode.json` from the web UI and add the relevant
credentials. See <https://opencode.ai/docs/providers/>.

## Layout

```
.
├── Dockerfile           # node + bun + opencode + continuous-code (pinned)
├── docker-compose.yml   # one service, one named volume, port 7878
├── entrypoint.sh        # seeds /data on first run, launches opencode web
├── .env.example         # OLLAMA_API_KEY=
├── .gitignore           # ignores .env
└── README.md
```

## License

MIT.
