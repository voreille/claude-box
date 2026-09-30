#!/usr/bin/env bash
# Build the claude-box image for the current user, create .env and put the launcher on PATH.
# Extra arguments are passed to `docker build` (e.g. ./install.sh --no-cache).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

CONTEXT="${CLAUDE_BOX_CONTEXT:-rootless}"
IMAGE="${CLAUDE_BOX_IMAGE:-claude-box}"

if ! docker context inspect "$CONTEXT" >/dev/null 2>&1; then
  echo "Docker context '$CONTEXT' not found. Install rootless Docker first (see README)." >&2
  exit 1
fi

docker --context "$CONTEXT" build -t "$IMAGE" "$@" .

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created $PWD/.env from .env.example: edit it to add caches, data folders, GPUs..."
fi

mkdir -p "$HOME/bin"
ln -sf "$PWD/claude-box" "$HOME/bin/claude-box"
echo
echo "Installed: $HOME/bin/claude-box"
case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) echo "Add ~/bin to your PATH:  echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc" ;;
esac
