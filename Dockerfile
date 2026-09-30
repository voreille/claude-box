# claude-box image: Claude Code + uv + git, nothing else.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git ripgrep procps less \
 && rm -rf /var/lib/apt/lists/*

# uv (Python package / project manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Claude Code, copied to a system path so it runs regardless of $HOME
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && cp -L /root/.local/bin/claude /usr/local/bin/claude \
 && rm -rf /root/.local /root/.claude /root/.claude.json

# Updates are done by rebuilding the image (./install.sh --no-cache)
ENV DISABLE_AUTOUPDATER=1
