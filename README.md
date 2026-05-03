# ccodebox

A one-command, containerized [Claude Code](https://claude.com/claude-code) workspace.

`ccodebox` spawns a fresh Ubuntu 24.04 Docker container with `claude`, `opencode`,
`uv`, `ripgrep`, `tmux`, and a few other tools pre-installed, opens it in a new
[Alacritty](https://alacritty.org/) window, and mounts the current project's
`./mount` directory as `/workspace` inside the container. Your Claude Code
configuration (auth, settings, plugins) is persisted between runs.

Optionally, on first launch the entrypoint offers to install
[Continuous Claude v3](https://github.com/parcadei/Continuous-Claude-v3), a
community workflow toolkit (hooks, skills, agents) for Claude Code.

## Why

- **Sandbox.** Claude Code runs as root inside a container; it cannot touch
  your host filesystem outside the project's `mount/` directory.
- **Reproducible.** Every project gets the same image and the same toolchain.
- **Persistent config.** `~/.claude` and `~/.claude.json` are stored under
  `~/.local/share/coding-container-template/config/` on the host and survive
  container restarts.
- **One command.** `cd` into a project, run `ccodebox`, get a coding shell.
- **Auto-accept on.** Permission prompts are disabled by default
  (`bypassPermissions`); see [Auto-accept](#auto-accept) below.

## Requirements

- Linux host with `systemd` (the wrapper does `systemctl start docker`)
- [Docker](https://docs.docker.com/engine/install/) (running, with the host
  socket at `/var/run/docker.sock`)
- [Alacritty](https://alacritty.org/)
- `bash` or `zsh`
- Run as `root` (the template lives under `/root/...` and the container runs
  as root). The simplest path is `sudo -i` first.

## Install

```bash
sudo -i
git clone https://github.com/sahelea1/ccodebox.git
cd ccodebox
./install.sh
```

The installer:

1. Copies `Dockerfile` and `start.sh` to `~/.local/share/coding-container-template/`.
2. Appends a `ccodebox` shell function to `~/.zshrc` or `~/.bashrc`
   (auto-detected from `$SHELL`; pass `--rc <path>` to override).

Reload your shell, or `source` your rc file, to pick up the new function:

```bash
source ~/.zshrc   # or ~/.bashrc
```

## Usage

In any project directory:

```bash
ccodebox
```

This will:

1. Build the Docker image on first run (cached afterwards).
2. Create `./mount/` if it doesn't exist (mounted as `/workspace`).
3. Open a new Alacritty window with a Bash session inside the container.

Rebuild the image after editing the `Dockerfile`:

```bash
ccodebox --rebuild
```

### Inside the container

| Command         | What it does                                                |
| --------------- | ----------------------------------------------------------- |
| `claude-opus`   | Claude Code with Opus as main model, Sonnet as subagents    |
| `claude`        | Claude Code with default settings                           |
| `cc-setup`      | Run the Continuous Claude setup wizard                      |
| `cc-update`     | Update the Continuous Claude installation                   |
| `cc-uninstall`  | Remove the Continuous Claude hooks/skills/agents            |

The aliases are added to `/root/.bashrc` by the entrypoint on first launch.

### Auto-accept

Because the container is sandboxed (no host filesystem access outside
`./mount`, no host shell), it's safe to skip Claude Code's per-tool
permission prompts. The entrypoint enables this two ways, both of which
trigger Claude Code's `bypassPermissions` mode:

1. It merges `permissions.defaultMode = "bypassPermissions"` into
   `~/.claude/settings.json` (preserving any existing `allow` / `deny` /
   `env` / hooks). This is the canonical Claude Code switch.
2. The `claude` and `claude-opus` aliases also pass
   `--dangerously-skip-permissions`, as a belt-and-suspenders fallback in
   case `settings.json` is overridden.

Result: every tool call (Bash, Edit, Write, MCP, ...) is auto-accepted
inside the container.

To turn it off, edit `~/.claude/settings.json` on the host and either set
`"defaultMode"` to `"default"` / `"acceptEdits"` or delete the key. You can
also bypass the alias for a single run with `command claude` or
`\claude`.

### Continuous Claude (optional)

On first run the entrypoint asks whether to install
[Continuous Claude v3](https://github.com/parcadei/Continuous-Claude-v3).
It's a community project, not Anthropic. Saying "no" leaves the container
fully usable with stock Claude Code; you can run `cc-setup` later.

## Workflow cheatsheet

A short reference for the Continuous Claude workflows. Skip if you didn't
install it.

### Start a session

```bash
cd /workspace/my-project
claude-opus
```

Inside Claude:

```
/workflow
```

### New project (greenfield)

```
/build greenfield "AI productivity app with auth, dashboard and multi-LLM routing"

Use Continuous Claude workflows.
Keep context minimal and sufficient.
Document architecture decisions.
Create/update handoff after milestones.
Do not overengineer.
```

### Extending an existing project (brownfield)

```
/build brownfield "add image upload to the existing chat"

Use existing conventions.
Do not scan the whole repo.
Use agents for exploration if needed.
Before editing, identify the minimal file set.
Run targeted verification.
Update handoff.
```

### Fix a bug

```
/fix bug "login redirects to wrong page after OAuth"

Find root cause first.
Make the smallest safe fix.
Run targeted verification.
Update handoff with cause and fix.
```

### Explore a codebase

```
/explore
/explore "understand auth flow and API structure"
```

### Risk-check a large change

```
/premortem "migrate auth from custom sessions to Auth.js"
```

### End of session

```
Create a handoff now.

Include:
- current goal
- completed work
- files changed
- decisions made
- known issues
- tests run and results
- exact next steps
```

### Resume a session

```
resume_handoff

Summarize where we are, then continue with the next concrete task.
```

### Default prompt prefix

```
Use Continuous Claude workflows.
Keep context minimal and sufficient.
Do not scan the whole repo.
Use subagents for broad exploration.
Before editing, identify the minimal file set.
Run the smallest relevant verification.
Update handoff when done.
```

### Glossary

| Term         | Meaning                                                |
| ------------ | ------------------------------------------------------ |
| `greenfield` | new project from scratch                               |
| `brownfield` | extending an existing project                          |
| `handoff`    | saved working state for a later session                |
| `agent`      | offloaded helper with its own context window           |
| `skill`      | specialized workflow / capability                      |
| `hook`       | automatic rule or action triggered in the background   |

## Update / uninstall

Update the host-side template files after `git pull`:

```bash
cd /root/ccodebox
git pull
./install.sh
```

Uninstall:

```bash
./install.sh --uninstall
```

This removes the `ccodebox` function from your rc file and offers to delete
`~/.local/share/coding-container-template/`. To remove the Docker image too:

```bash
docker rmi claude-opencode-cli:latest
```

## Troubleshooting

- **`docker: Cannot connect to the Docker daemon`** — `systemctl start docker`.
  The `ccodebox` function tries this for you.
- **Alacritty doesn't open** — install it via your distro's package manager
  (`apt install alacritty`, `pacman -S alacritty`, ...).
- **`/var/run/docker.sock` not mounted** — the entrypoint warns if the host
  Docker socket isn't visible inside the container. Continuous Claude needs it
  to run PostgreSQL. Make sure Docker is running on the host before launching.
- **Verify the GitHub HTTPS rewrite** (the image forces HTTPS clones over SSH):

  ```bash
  git config --global --get-regexp '^url\.https://github\.com/'
  ```

## Layout

```
.
├── Dockerfile        # base image: Ubuntu 24.04 + claude/opencode/uv/...
├── start.sh          # builds the image (if needed) and opens an Alacritty session
├── install.sh        # installs the template + shell function
└── README.md
```






Initial prompt template:
















/build greenfield "<PROJECT_NAME>"

Initialize this project for Continuous Claude v3 usage.

Important execution mode:
Main Opus is the orchestrator, not the bulk worker.

Main Opus should only keep:
- short summaries
- architecture decisions
- minimal implementation plans
- changed file lists
- verification results
- unresolved blockers
- next steps

Use Sonnet agents/tools for:
- broad repo exploration
- file discovery
- fixture/page-source/log inspection
- test failure analysis
- documentation sync
- QA/security review
- release/build checks

Context rules:
- Do not scan the whole repo unnecessarily.
- Do not load large raw files, screenshots, generated files, build outputs, lockfiles, node_modules, vendor folders or long logs into main context.
- Agents may inspect large files and return concise summaries.
- Before editing, identify the minimal file set.
- Prefer project docs/contracts/maps before implementation files.
- If context grows too large, stop, create/update handoff, and tell me the next prompt to run.

Goal:
Create a reusable project context layer so future tasks can be done with low main-context usage.

First inspect the project minimally and create/update these files if useful:
- CLAUDE.md
- docs/ai/project-map.md
- docs/ai/current-state.md
- docs/ai/architecture.md
- docs/ai/api-contract.md, only if the project has APIs
- docs/ai/release-process.md, only if the project has a build/release flow
- docs/ai/testing.md
- docs/ai/decisions.md
- docs/ai/handoff.md

Keep these files concise and practical.
Do not create unnecessary documentation.

The docs should answer:
- What does this project do?
- What stack/frameworks are used?
- Where are important files/directories?
- How is the app started locally?
- How is it built/tested/linted?
- What are the current supported features?
- What are fragile/risky areas?
- What should future Claude sessions read first?
- What files should future Claude sessions avoid reading unless needed?
- What are the current next tasks?

CLAUDE.md should be short and act as a router:
- tell Claude what docs to read for which task type
- define Main Opus as orchestrator
- tell Claude to use agents/tools for broad exploration
- tell Claude not to scan the whole repo
- tell Claude to update handoff/current-state after meaningful work

Also configure project workflow:
1. Detect existing branch/state.
2. Do not implement product features yet.
3. Do not do broad refactors.
4. Do not change runtime behavior unless needed for setup.
5. Add only Continuous-Claude/project-context documentation/config files.
6. Run only safe verification commands needed to understand the project.
7. Create/update handoff.
8. Commit the added/updated context files to the current branch. Do not push.

Final response:
- project summary
- files created/updated
- verification commands run
- commit hash
- recommended next prompt
