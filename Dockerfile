# ── Base image: lightweight Debian ───────────────────────────────────────────
FROM debian:bookworm-slim

# Avoid interactive prompts during package install
ENV DEBIAN_FRONTEND=noninteractive

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      gnupg \
      jq \
      make \
      python3 \
      python3-pip \
      python3-venv \
      unzip \
      xz-utils \
    && rm -rf /var/lib/apt/lists/*

# ── Headless keyring support (for Copilot CLI credential storage) ─────────────
# gnome-keyring-daemon provides a Secret Service backend without a desktop session
RUN apt-get update && apt-get install -y --no-install-recommends \
      dbus \
      gnome-keyring \
      libsecret-1-0 \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 22 LTS (via NodeSource) ──────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── GitHub Copilot CLI ────────────────────────────────────────────────────────
# Installs the `copilot` command globally via npm
RUN npm install -g @github/copilot

# ── Azure CLI (isolated in /opt/az via venv) ──────────────────────────────────
# Using a Python venv keeps it isolated and avoids system package conflicts
RUN python3 -m venv /opt/az/venv \
    && /opt/az/venv/bin/pip install --no-cache-dir azure-cli

# Create the real az shim (called by the wrapper after blocklist check)
RUN mkdir -p /opt/az/bin \
    && printf '#!/usr/bin/env bash\nexec /opt/az/venv/bin/az "$@"\n' > /opt/az/bin/az-real \
    && chmod +x /opt/az/bin/az-real

# ── AWS CLI v2 (official binary bundle) ──────────────────────────────────────
RUN ARCH="$(uname -m)" \
    && if [ "$ARCH" = "aarch64" ]; then AWS_ARCH="aarch64"; else AWS_ARCH="x86_64"; fi \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp/awscli \
    && /tmp/awscli/aws/install --install-dir /opt/aws --bin-dir /opt/aws/bin-install \
    && mkdir -p /opt/aws/bin \
    && printf '#!/usr/bin/env bash\nexec /opt/aws/bin-install/aws "$@"\n' > /opt/aws/bin/aws-real \
    && chmod +x /opt/aws/bin/aws-real \
    && rm -rf /tmp/awscliv2.zip /tmp/awscli

# ── Sandbox wrapper scripts ───────────────────────────────────────────────────
# These live in /usr/local/bin and take priority over any other az/aws in PATH
COPY scripts/az-wrapper.sh  /usr/local/bin/az
COPY scripts/aws-wrapper.sh /usr/local/bin/aws
COPY scripts/entrypoint.sh  /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/az /usr/local/bin/aws /usr/local/bin/entrypoint.sh

# ── Workspace ─────────────────────────────────────────────────────────────────
WORKDIR /workspace

ENTRYPOINT ["entrypoint.sh"]
CMD ["copilot", "--allow-all-tools"]
