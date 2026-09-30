#!/bin/sh
# uv wrapper used inside claude-box: gives every project its own venv under
# $HOME/venvs (i.e. ~/.claude-box/venvs on the host) instead of <project>/.venv,
# so the host's .venv folders are never used or overwritten by the container.
if [ -z "${UV_PROJECT_ENVIRONMENT:-}" ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$root" ]; then
    # Not a git repo: nearest parent folder with a pyproject.toml, else cwd
    dir=$(pwd -P)
    while [ "$dir" != "/" ] && [ ! -f "$dir/pyproject.toml" ]; do dir=$(dirname "$dir"); done
    if [ -f "$dir/pyproject.toml" ]; then root=$dir; else root=$(pwd -P); fi
  fi
  hash=$(printf '%s' "$root" | sha1sum | cut -c1-8)
  UV_PROJECT_ENVIRONMENT="$HOME/venvs/$(basename "$root")-$hash"
  export UV_PROJECT_ENVIRONMENT
fi
exec /usr/local/lib/uv/uv "$@"
