#!/usr/bin/env bash
# az-wrapper.sh — Intercepts destructive Azure CLI commands.
# The real az binary lives at /opt/az/bin/az-real.

set -euo pipefail

LOG_FILE="/sandbox-logs/sandbox-blocked.log"
FULL_CMD="az $*"

_block() {
  local reason="$1"
  local msg="[SANDBOX BLOCKED] ${FULL_CMD} — ${reason}"
  echo "${msg}" >&2
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") ${msg}" >> "${LOG_FILE}" 2>/dev/null || true
  exit 1
}

# ── Blocklist: loaded from config file ───────────────────────────────────────
# Edit /etc/sandbox/az-blocklist.conf to add/remove patterns.
# Patterns are matched against the first 3 positional args only — NOT flag values.
BLOCKED_CONF="/etc/sandbox/az-blocklist.conf"
BLOCKED_PATTERNS=()
if [[ -f "$BLOCKED_CONF" ]]; then
  while IFS= read -r line; do
    # skip blank lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue
    BLOCKED_PATTERNS+=("$line")
  done < "$BLOCKED_CONF"
fi

# ── Parse args: collect positional args, detect --method flag value ───────────
POSITIONAL=()
NEXT_IS_METHOD_VAL=0
DETECTED_METHOD=""

for arg in "$@"; do
  if [[ "${NEXT_IS_METHOD_VAL}" == "1" ]]; then
    DETECTED_METHOD="${arg}"
    NEXT_IS_METHOD_VAL=0
    continue
  fi
  if [[ "$arg" == "--method" || "$arg" == "-m" ]]; then
    NEXT_IS_METHOD_VAL=1
    continue
  fi
  [[ "$arg" == -* ]] && continue
  POSITIONAL+=("$arg")
done

# ── Special case: az rest --method DELETE ────────────────────────────────────
# Without this, "az rest --method DELETE --uri ..." would bypass the wrapper
# entirely because --method is a flag and DELETE is its value, not a positional arg.
if [[ "${#POSITIONAL[@]}" -gt 0 && "${POSITIONAL[0]}" == "rest" ]]; then
  if [[ "${DETECTED_METHOD,,}" == "delete" ]]; then
    _block "'az rest --method ${DETECTED_METHOD}' performs a REST DELETE — forbidden"
  fi
fi

# ── Check first 3 positional args (group [subgroup] subcommand) ──────────────
# Azure CLI structure: az <group> [<subgroup>] <subcommand> [options]
# Checking only the first 3 positional args prevents matching flag values
# that happen to contain forbidden words (e.g. resource names, tag values).
COUNT=0
for arg in "${POSITIONAL[@]}"; do
  COUNT=$((COUNT + 1))
  [[ $COUNT -gt 3 ]] && break
  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if [[ "$arg" == *"${pattern}"* ]]; then
      _block "argument '${arg}' matches forbidden pattern '${pattern}'"
    fi
  done
done

# ── Pass through to the real az ──────────────────────────────────────────────
exec /opt/az/bin/az-real "$@"
