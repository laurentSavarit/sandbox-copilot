#!/usr/bin/env bash
# aws-wrapper.sh — Intercepts destructive AWS CLI commands.
# The real aws binary lives at /opt/aws/bin/aws-real.

set -euo pipefail

LOG_FILE="/sandbox-logs/sandbox-blocked.log"
FULL_CMD="aws $*"

_block() {
  local reason="$1"
  local msg="[SANDBOX BLOCKED] ${FULL_CMD} — ${reason}"
  echo "${msg}" >&2
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") ${msg}" >> "${LOG_FILE}" 2>/dev/null || true
  exit 1
}

# ── Blocklist: loaded from config file ───────────────────────────────────────
# Edit /etc/sandbox/aws-blocklist.conf to add/remove patterns.
# Patterns are matched against POSITIONAL[1] (the subcommand) only — NOT parameter values.
BLOCKED_CONF="/etc/sandbox/aws-blocklist.conf"
BLOCKED_PATTERNS=()
if [[ -f "$BLOCKED_CONF" ]]; then
  while IFS= read -r line; do
    # skip blank lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue
    BLOCKED_PATTERNS+=("$line")
  done < "$BLOCKED_CONF"
fi

# ── Parse args: collect positional args, detect --delete* flags ───────────────
POSITIONAL=()
HAS_DELETE_FLAG=0

for arg in "$@"; do
  # Detect --delete and --delete-source-files flags (used by s3 sync/cp/mv)
  if [[ "$arg" == "--delete"* ]]; then
    HAS_DELETE_FLAG=1
    continue
  fi
  [[ "$arg" == -* ]] && continue
  POSITIONAL+=("$arg")
done

# Helper: service name (POSITIONAL[0]) and subcommand (POSITIONAL[1])
SVC="${POSITIONAL[0]:-}"
SUB="${POSITIONAL[1]:-}"

# ── Special cases: s3 high-level commands ────────────────────────────────────
if [[ "$SVC" == "s3" ]]; then
  case "$SUB" in
    rm)   _block "'s3 rm' deletes S3 objects — forbidden" ;;
    rb)   _block "'s3 rb' removes an S3 bucket — forbidden" ;;
    mv)   _block "'s3 mv' deletes the source after copying — forbidden" ;;
  esac
  if [[ "$SUB" == "sync" && "${HAS_DELETE_FLAG}" == "1" ]]; then
    _block "'s3 sync --delete' deletes destination objects not in source — forbidden"
  fi
fi

# ── Check the subcommand position against the blocklist ──────────────────────
if [[ -n "$SUB" ]]; then
  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if [[ "$SUB" == *"${pattern}"* ]]; then
      _block "subcommand '${SUB}' matches forbidden pattern '${pattern}'"
    fi
  done
fi

# ── Pass through to the real aws ─────────────────────────────────────────────
exec /opt/aws/bin/aws-real "$@"
