# claude-box

Run [Claude Code](https://code.claude.com/docs) inside a **rootless Docker container** so it can
only modify the project you are working on, and nothing else on the server.

## What it protects

| Location | Access from inside the box |
|---|---|
| The current git repo (+ folders passed with `--add-dir`) | read + write |
| `~/.claude-box` (Claude login, uv cache, venvs) | read + write |
| Data that the repo symlinks to, or listed in `.claude-box.mounts` or `CLAUDE_BOX_RO` | **read-only** |
| Folders listed in `CLAUDE_BOX_RW` in `.env` (e.g. the Hugging Face cache) | read + write |
| `~/.gitconfig` | read-only (so commits use your name) |
| Everything else (your home, other repos, other users, the system) | **not visible at all** |

Because Docker runs *rootless*, "root" inside the container is just **your own user** on the host:
files Claude creates belong to you, and even a container escape would not give more rights than you
already have.

What it does **not** protect: the repo itself. Claude can edit or delete anything in it, so
**commit before each session**, and keep important untracked outputs (results, checkpoints) outside
the repo. The container also has normal outgoing network access (needed for the Claude API and PyPI).

## Setup (once per user)

### 1. Install rootless Docker

Rootless Docker is installed per user. Because the system (rootful) Docker also runs on the
server, the setup tool needs `--force`:

```bash
dockerd-rootless-setuptool.sh install --force
systemctl --user enable --now docker
docker context ls            # should list "default" and "rootless"
```

You can keep using the normal daemon for other things; claude-box always uses the `rootless`
context explicitly. The two daemons do not share images or containers.

**Optional, for GPUs:**

```bash
nvidia-ctk runtime configure --runtime=docker --config=$HOME/.config/docker/daemon.json
systemctl --user restart docker
docker --context rootless run --rm --gpus all ubuntu nvidia-smi   # should list the GPUs
```

### 2. Build the image and install the launcher

```bash
git clone <this repo> ~/claude-box
cd ~/claude-box
./install.sh
```

This builds the `claude-box` image in your rootless daemon, creates your personal `.env` from
`.env.example` (`.env` is git-ignored), and links the launcher to `~/bin/claude-box`. If `~/bin` is
not on your `PATH`, the script tells you how to add it. All your settings live in that one `.env`
file, see [Settings](#settings-env).

### 3. First run and login

```bash
cd ~/workspaces/my-project
claude-box
```

Claude prints a login URL: open it in your local browser and paste the code back. The login is
stored in `~/.claude-box` and reused for every project.

## Usage

```bash
claude-box                                   # start Claude Code in the current repo
claude-box --dangerously-skip-permissions    # no confirmation prompts (the box is the boundary)
claude-box --continue                        # any claude argument is passed through
claude-box shell                             # bash in the same environment, for debugging
claude-box mounts --add-dir ../other-repo    # list what the box would see (read-write / read-only)
claude-box --add-dir ../other-repo          # also give access to another repo
CLAUDE_BOX_GPUS=all claude-box               # with GPUs (or set it in .env)
CLAUDE_BOX_DRY_RUN=1 claude-box              # print the docker command, run nothing
```

You can start it from any subfolder: the whole git repo is mounted (at the **same absolute path**
as on the host, so paths and relative symlinks behave the same inside and outside).

### Working on several repos

Claude only sees the repo you start it from. To give it more:

```bash
# Read-write access to other repos (mounted, and passed to Claude's own --add-dir)
cd ~/workspaces/repo-a
claude-box --add-dir ../repo-b ../repo-c

# Read-only access, e.g. a repo Claude should only look at for reference:
# add its path to .claude-box.mounts (see "Data and symlinks" below)

# Everything in a folder of repos, read-write (convenient, but less protection)
cd ~/workspaces
claude-box
```

In the last case, Claude can modify every repo in `~/workspaces`, so make sure they are all
committed. Symlink scanning then covers all repos; if that is slow, set `CLAUDE_BOX_AUTO_MOUNTS=0`
and use `.claude-box.mounts` in `~/workspaces`.

### Python / uv

Inside the box, `uv` is a small wrapper (`uv-shim.sh`) that gives each project its own venv in
`~/.claude-box/venvs/<project>-<hash>`, so your host `.venv` folders are never touched, even when
Claude works across several repos. Always go through `uv run ...` inside the box, since the
project's `.venv/bin/python` belongs to the host and won't work there. The first time, ask Claude to run `uv sync`. PyTorch wheels bring
their own CUDA libraries, so no CUDA image is needed.

### Data and symlinks

Symlinks inside the repo that point **outside** of it (e.g. `data/scorpion -> /mnt/nas/scorpion`)
are detected automatically and their targets are mounted **read-only** at the same path, so the
links keep working.

To mount extra folders, or a single parent folder instead of many small ones, create
`.claude-box.mounts` at the repo root, one path per line:

```
# read-only data
/mnt/nas/scorpion
~/datasets/shared   # ~ is expanded
```

If a repo has many symlinks to scattered places, list the parent folders in that file and set
`CLAUDE_BOX_AUTO_MOUNTS=0`.

## Settings (`.env`)

Everything is configured in `~/claude-box/.env` (created by `install.sh` from `.env.example`, never
committed). Format is `KEY=value`, one per line; `~` and `$HOME` are expanded. The file is parsed, not executed,
so nothing in it can run commands.

Path lists use `:` as separator, like `PATH`, with no spaces:

```bash
CLAUDE_BOX_RW=~/.cache/huggingface:~/.cache/torch
```

`CLAUDE_BOX_RW=folder1 folder2` does **not** work: it is read as a single path containing a space.

```bash
# Extra folders mounted READ-WRITE in every project (caches that can be re-downloaded)
CLAUDE_BOX_RW=~/.cache/huggingface
# Extra folders mounted READ-ONLY in every project
CLAUDE_BOX_RO=/mnt/nas/shared_datasets
# GPUs (empty = none)
CLAUDE_BOX_GPUS=all

# Any other line becomes an environment variable inside the box
HF_HOME=~/.cache/huggingface
# A bare name passes the host's current value (e.g. exported in ~/.bashrc)
WANDB_API_KEY
```

| Key | Default | Meaning |
|---|---|---|
| `CLAUDE_BOX_RW` | *(none)* | Extra read-write folders (not treated as projects) |
| `CLAUDE_BOX_RO` | *(none)* | Extra read-only folders, for every project |
| `CLAUDE_BOX_GPUS` | *(none)* | Value passed to `docker --gpus` (e.g. `all`, `device=0`) |
| `CLAUDE_BOX_AUTO_MOUNTS` | `1` | Auto-mount symlink targets read-only |
| `CLAUDE_BOX_CONTEXT` | `rootless` | Docker context to use |
| `CLAUDE_BOX_IMAGE` | `claude-box` | Image name |
| `CLAUDE_BOX_HOME` | `~/.claude-box` | Persistent state directory |
| `CLAUDE_BOX_DRY_RUN` | `0` | Print the docker command instead of running it |

A `CLAUDE_BOX_*` variable set in your shell overrides `.env` for one run, e.g.
`CLAUDE_BOX_GPUS=all claude-box`.

### Hugging Face and other caches

Inside the box `$HOME` is `/box`, so tools that store things in `~/.cache` would start from an empty
cache and re-download everything. The default `.env` therefore shares your Hugging Face cache
**read-write** and sets `HF_HOME` so the hub library finds it. Read-write is deliberate: new models
can still be downloaded, and the worst case is a deleted cache entry you can re-download. Your HF
token (for gated models) lives in that folder, so gated models work too. For torch hub weights,
uncomment the `TORCH_HOME` line and add `~/.cache/torch` to `CLAUDE_BOX_RW`.

Paths that are symlinks (e.g. `~/.cache/huggingface -> /mnt/nas/hf`) are handled: both the link path
and its target are mounted. Check the result with `claude-box mounts`.

Rule of thumb: **read-write** for anything that can be re-downloaded or regenerated, **read-only**
for anything you cannot afford to lose.

## Updating Claude Code

Auto-update is disabled inside the container. To update, rebuild the image:

```bash
cd ~/claude-box && git pull && ./install.sh --no-cache
```

## Troubleshooting

- **`docker context 'rootless' not found`**: rootless Docker is not installed or not running
  (`systemctl --user status docker`).
- **Files owned by a strange UID on the host**: don't add `--user` to the docker command. In rootless
  mode, root inside the container already maps to you.
- **A symlink is broken inside the box**: its target doesn't exist on the host, or auto-mounts are
  disabled. Add the target to `.claude-box.mounts`.
- **`--dangerously-skip-permissions` refuses to run as root**: the launcher sets `IS_SANDBOX=1`,
  which is the usual workaround. If a Claude Code update changes this, check the Claude Code docs or
  issues.
- **The launcher refuses to start**: it won't mount `/` or your home directory read-write (neither
  as the current folder nor with `--add-dir`). Run it from inside a project folder.
