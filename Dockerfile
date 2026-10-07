# claude-box image: Claude Code + uv + git, nothing else.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git ripgrep procps less \
    build-essential \
 && rm -rf /var/lib/apt/lists/*

# uv, behind a small wrapper that keeps one venv per project in the box home
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/lib/uv/uv
COPY --from=ghcr.io/astral-sh/uv:latest /uvx /usr/local/lib/uv/uvx
COPY uv-shim.sh /usr/local/bin/uv
RUN chmod 755 /usr/local/bin/uv && ln -s /usr/local/lib/uv/uvx /usr/local/bin/uvx

# Claude Code, copied to a system path so it runs regardless of $HOME
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && cp -L /root/.local/bin/claude /usr/local/bin/claude \
 && rm -rf /root/.local /root/.claude /root/.claude.json

# Updates are done by rebuilding the image (./install.sh --no-cache)
ENV DISABLE_AUTOUPDATER=1
