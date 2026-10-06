# Environment: claude-box

You run inside a rootless Docker container (claude-box). Only the current repo,
folders passed with --add-dir, and a few read-only data/cache folders are visible.
HOME is /box.

## Python
- Always use uv: run `uv sync` once if needed, then `uv run ...`.
- `uv` is a wrapper that keeps one venv per project in /box/venvs/. That is the
  only valid environment. The project's .venv is the host's and is hidden here.
- Never create venvs elsewhere (/tmp, scratch dirs), never use pip directly, never
  point a Python at another environment's site-packages.
- The first `uv sync` of a project downloads large packages (torch); later syncs
  use the cache in /box/.cache/uv.

## Hardware
- Check GPU availability with `nvidia-smi` before planning GPU work. If there is
  no GPU, say so instead of working around it.

## Git
- No git credentials here: commit locally, never push.
