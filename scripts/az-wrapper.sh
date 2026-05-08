#!/usr/bin/env bash
# az-wrapper.sh — Intercepts destructive Azure CLI commands.
# The real az binary lives at /opt/az/bin/az-real.

set -euo pipefail

LOG_FILE="/sandbox-logs/sandbox-blocked.log"

# ── Blocklist: positional arg substrings that are forbidden ──────────────────
BLOCKED_PATTERNS=(
  "delete"
  "remove"
  "purge"
)

# ── Check every positional argument against the blocklist ───────────────────
for arg in "$@"; do
  # Skip flags (starting with -)
  [[ "$arg" == -* ]] && continue

  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if [[ "$arg" == *"${pattern}"* ]]; then
      msg="[SANDBOX BLOCKED] az $* — argument '${arg}' matches forbidden pattern '${pattern}'"
      echo "${msg}" >&2
      echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") ${msg}" >> "${LOG_FILE}" 2>/dev/null || true
      exit 1
    fi
  done
done

# ── Pass through to the real az ──────────────────────────────────────────────
exec /opt/az/bin/az-real "$@"
