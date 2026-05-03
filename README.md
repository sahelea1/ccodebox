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
