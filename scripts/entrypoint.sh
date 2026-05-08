#!/usr/bin/env bash
# entrypoint.sh — Sandbox startup script for the GitHub Copilot CLI container.

set -euo pipefail

# ── Headless keyring (avoids "system vault not available" warning) ───────────
# Start a D-Bus session then unlock gnome-keyring with an empty password.
# This gives the Copilot CLI a working Secret Service backend for token storage.
if command -v dbus-daemon &>/dev/null && command -v gnome-keyring-daemon &>/dev/null; then
  DBUS_ADDR=$(dbus-daemon --fork --session --print-address 2>/dev/null) || true
  if [[ -n "${DBUS_ADDR}" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="${DBUS_ADDR}"
    echo -n "" | gnome-keyring-daemon --unlock --components=secrets --daemonize \
      >/dev/null 2>&1 || true
  fi
fi

# ── Ensure log file exists and is writable ───────────────────────────────────
mkdir -p /sandbox-logs && touch /sandbox-logs/sandbox-blocked.log 2>/dev/null || true

# ── Daemon mode (sleep infinity) — skip interactive banner ───────────────────
if [[ "${1:-}" == "sleep" ]]; then
  exec "$@"
fi

# ── Banner (interactive sessions only) ───────────────────────────────────────
cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║           GitHub Copilot CLI — Sandbox Environment          ║
╠══════════════════════════════════════════════════════════════╣
║  BLOCKED commands:                                          ║
║    az  → delete, remove, purge (any positional arg)        ║
║    aws → delete-*, terminate-*, remove-*, s3 rm, purge     ║
║                                                              ║
║  Blocked attempts are logged to:                            ║
║    logs/sandbox-blocked.log  (in your repo)                 ║
║                                                              ║
║  Workspace: current host directory mounted at /workspace    ║
║  Credentials: ~/.aws and ~/.azure mounted read-only         ║
╚══════════════════════════════════════════════════════════════╝
EOF

# ── Auth check ───────────────────────────────────────────────────────────────
TOKEN="${COPILOT_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
if [[ -z "${TOKEN}" ]]; then
  echo ""
  echo "⚠  WARNING: No GitHub token found in environment."
  echo "   Set COPILOT_GITHUB_TOKEN (or GH_TOKEN / GITHUB_TOKEN) before running copilot."
  echo ""
fi

# ── Execute the provided command (or drop to bash) ──────────────────────────
if [[ $# -eq 0 ]]; then
  exec /bin/bash
else
  exec "$@"
fi
