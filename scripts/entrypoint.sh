#!/usr/bin/env bash
# entrypoint.sh — Sandbox startup script for the GitHub Copilot CLI container.

set -euo pipefail

# ── Headless keyring (avoids "system vault not available" warning) ───────────
# Start a D-Bus session, then unlock gnome-keyring with an empty password.
# --start (not --daemonize) prints GNOME_KEYRING_CONTROL + GNOME_KEYRING_PID
# to stdout so we can eval them — without this, libsecret can't find the socket.
if command -v dbus-daemon &>/dev/null && command -v gnome-keyring-daemon &>/dev/null; then
  DBUS_ADDR=$(dbus-daemon --session --fork --print-address 2>/dev/null) || true
  if [[ -n "${DBUS_ADDR:-}" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="${DBUS_ADDR}"
    GKD_OUT=$(echo "" | gnome-keyring-daemon --unlock --start --components=secrets 2>/dev/null) || true
    eval "${GKD_OUT}" 2>/dev/null || true
    export GNOME_KEYRING_CONTROL GNOME_KEYRING_PID 2>/dev/null || true
  fi
fi

# ── Ensure log file exists and is writable ───────────────────────────────────
mkdir -p /sandbox-logs && touch /sandbox-logs/sandbox-blocked.log 2>/dev/null || true

# ── Azure CLI writable config dir ────────────────────────────────────────────
# ~/.azure is mounted read-only (host credentials). Azure CLI writes runtime
# files (azureProfile.json, telemetry, logs) on every invocation — so we
# shadow the mount by copying credentials to a writable tmpfs dir and pointing
# AZURE_CONFIG_DIR there. The original mount is never modified.
export AZURE_CONFIG_DIR=/tmp/azure-config
mkdir -p "${AZURE_CONFIG_DIR}"
if [[ -d /root/.azure && -n "$(ls -A /root/.azure 2>/dev/null)" ]]; then
  cp -a /root/.azure/. "${AZURE_CONFIG_DIR}/"
fi

# ── Daemon mode (sleep infinity) — skip interactive banner ───────────────────
if [[ "${1:-}" == "sleep" ]]; then
  exec "$@"
fi

# ── Banner (interactive sessions only) ───────────────────────────────────────
cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║           GitHub Copilot CLI — Sandbox Environment           ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Destructive az/aws commands are blocked and logged.         ║
║  Customize:    config/az-blocklist.conf                      ║
║                config/aws-blocklist.conf                     ║
║                                                              ║
║  Blocked log:  logs/sandbox-blocked.log                      ║
║  Workspace:    /workspace                                    ║
║  Credentials:  ~/.aws and ~/.azure  (read-only)              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF

# ── Execute the provided command (or drop to bash) ──────────────────────────
if [[ $# -eq 0 ]]; then
  exec /bin/bash
else
  exec "$@"
fi
