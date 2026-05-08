#!/usr/bin/env bash
# aws-wrapper.sh — Intercepts destructive AWS CLI commands.
# The real aws binary lives at /opt/aws/bin/aws-real.

set -euo pipefail

LOG_FILE="/sandbox-logs/sandbox-blocked.log"

# ── Blocklist: positional arg substrings that are forbidden ──────────────────
BLOCKED_PATTERNS=(
  "delete-"
  "terminate-"
  "remove-"
  "deregister-"
  "destroy"
  "purge"
)

# ── Special case: "s3 rm" (service + subcommand combination) ────────────────
# Check for: aws s3 rm or aws s3api delete-object etc.
ARGS=("$@")
for i in "${!ARGS[@]}"; do
  arg="${ARGS[$i]}"
  [[ "$arg" == -* ]] && continue

  # s3 rm special case
  if [[ "$arg" == "s3" ]] && [[ "${ARGS[$((i+1))]+_}" ]] && [[ "${ARGS[$((i+1))]}" == "rm" ]]; then
    msg="[SANDBOX BLOCKED] aws $* — 's3 rm' is forbidden"
    echo "${msg}" >&2
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") ${msg}" >> "${LOG_FILE}" 2>/dev/null || true
    exit 1
  fi

  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if [[ "$arg" == *"${pattern}"* ]]; then
      msg="[SANDBOX BLOCKED] aws $* — argument '${arg}' matches forbidden pattern '${pattern}'"
      echo "${msg}" >&2
      echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") ${msg}" >> "${LOG_FILE}" 2>/dev/null || true
      exit 1
    fi
  done
done

# ── Pass through to the real aws ─────────────────────────────────────────────
exec /opt/aws/bin/aws-real "$@"
