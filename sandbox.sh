#!/usr/bin/env bash
# Run the GitHub Copilot CLI sandbox with your current directory mounted as workspace.
#
# A single persistent container is used so that auth (login, keyring) is preserved
# across sessions. Multiple terminals can connect simultaneously.
#
# Usage:
#   copilot-sandbox                       → copilot --allow-all-tools (yolo mode)
#   copilot-sandbox bash                  → debug shell
#   copilot-sandbox stop                  → stop the container (state preserved)
#   copilot-sandbox destroy               → stop + remove the container
#
# Install globally:
#   make install   (creates /usr/local/bin/copilot-sandbox → this script)

set -euo pipefail

# ── Resolve symlink so SANDBOX_DIR always points to the real script location ─
_SCRIPT="${BASH_SOURCE[0]}"
if [[ -L "$_SCRIPT" ]]; then
  _SCRIPT="$(readlink "$_SCRIPT")"
fi
SANDBOX_DIR="$(cd "$(dirname "$_SCRIPT")" && pwd)"

IMAGE="sandbox-copilot:latest"
LOGS_DIR="$SANDBOX_DIR/logs"
# Named volume for copilot auth state (keyring, config) — avoids mounting $HOME
AUTH_VOLUME="copilot-auth"

mkdir -p "$LOGS_DIR"

# ── Default command ───────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  set -- copilot --allow-all-tools
fi

# ── Volume / env args ─────────────────────────────────────────────────────────
VOL_ARGS=(
  # Auth state (copilot config, session DB, credentials) persisted across sessions
  -v "${AUTH_VOLUME}:/root/.copilot"
  # Current project directory as workspace
  -v "$(pwd):/workspace"
  # Block log accessible from host
  -v "$LOGS_DIR:/sandbox-logs"
)
[[ -d "$HOME/.aws" ]]   && VOL_ARGS+=(-v "$HOME/.aws:/root/.aws:ro")
[[ -d "$HOME/.azure" ]] && VOL_ARGS+=(-v "$HOME/.azure:/root/.azure:ro")

exec docker run --rm -it \
  "${VOL_ARGS[@]}" \
  -w /workspace \
  "$IMAGE" \
  "$@"
