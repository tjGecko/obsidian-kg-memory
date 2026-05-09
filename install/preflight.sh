#!/usr/bin/env bash
# preflight.sh — Fail fast before any install.
# Emits machine-readable JSON to stdout; human-readable log to stderr.
# Exit 0 if all checks pass; non-zero otherwise.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# Load pinned versions for the macOS minimum.
[[ -f "$SCRIPT_DIR/versions.env" ]] && source "$SCRIPT_DIR/versions.env"
MACOS_MIN_MAJOR="${MACOS_MIN_MAJOR:-13}"
DISK_MIN_GB="${DISK_MIN_GB:-10}"

declare -a checks=()
overall_passed=true

check() {
  local name="$1" passed="$2" actual="$3" required="$4" code="${5:-}"
  checks+=("$(jq -nc \
    --arg name "$name" --argjson passed "$passed" \
    --arg actual "$actual" --arg required "$required" --arg code "$code" \
    '{name: $name, passed: $passed, actual: $actual, required: $required, error_code: (if $code == "" then null else $code end)}')")
  if [[ "$passed" != "true" ]]; then overall_passed=false; fi
  if [[ "$passed" == "true" ]]; then log_ok "$name"; else log_err "$name (got: $actual; need: $required)"; fi
}

# ── Platform ───────────────────────────────────────────────────────────────
if [[ "$(uname -s)" == "Darwin" ]]; then
  check "platform_macos" true "Darwin" "Darwin"
else
  check "platform_macos" false "$(uname -s)" "Darwin" "wrong_platform"
  printf '%s\n' "$(jq -nc --argjson checks "[$(IFS=,; echo "${checks[*]}")]" '{passed: false, checks: $checks}')"
  exit 1
fi

# ── macOS version ──────────────────────────────────────────────────────────
macos_ver=$(sw_vers -productVersion 2>/dev/null || echo "0.0")
macos_major="${macos_ver%%.*}"
if [[ "$macos_major" -ge "$MACOS_MIN_MAJOR" ]]; then
  check "macos_version" true "$macos_ver" "${MACOS_MIN_MAJOR}.0+"
else
  check "macos_version" false "$macos_ver" "${MACOS_MIN_MAJOR}.0+" "macos_too_old"
fi

# ── Architecture ───────────────────────────────────────────────────────────
arch_val="$(uname -m)"
case "$arch_val" in
  arm64|x86_64) check "arch_supported" true "$arch_val" "arm64|x86_64" ;;
  *)            check "arch_supported" false "$arch_val" "arm64|x86_64" "arch_unsupported" ;;
esac

# ── Disk space ─────────────────────────────────────────────────────────────
free_gb=$(df -g / | awk 'NR==2 {print $4}')
if [[ "$free_gb" -ge "$DISK_MIN_GB" ]]; then
  check "disk_space_gb" true "$free_gb" "${DISK_MIN_GB}+"
else
  check "disk_space_gb" false "$free_gb" "${DISK_MIN_GB}+" "disk_low"
fi

# ── Admin / sudo ───────────────────────────────────────────────────────────
# Don't actually prompt for password — just check membership in admin group.
if id -Gn "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx admin; then
  check "user_is_admin" true "$USER in admin group" "admin"
else
  check "user_is_admin" false "$USER not in admin group" "admin" "not_admin"
fi

# ── Network reachability ───────────────────────────────────────────────────
declare -A endpoints=(
  ["github"]="https://api.github.com"
  ["homebrew"]="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  ["npm"]="https://registry.npmjs.org/-/ping"
  ["openai"]="https://api.openai.com"
  ["aqua_voice"]="https://aqua-desktop-builds.s3.us-east-1.amazonaws.com"
  ["nous_research"]="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"
)

for label in "${!endpoints[@]}"; do
  url="${endpoints[$label]}"
  if curl -fsS --connect-timeout 5 --max-time 10 -o /dev/null "$url" 2>/dev/null; then
    check "net_$label" true "reachable" "reachable"
  else
    check "net_$label" false "unreachable" "reachable" "network_unreachable"
  fi
done

# ── Existing brew at non-standard path ─────────────────────────────────────
if command -v brew >/dev/null 2>&1; then
  brew_path="$(command -v brew)"
  case "$brew_path" in
    /opt/homebrew/bin/brew|/usr/local/bin/brew) check "brew_path_standard" true "$brew_path" "/opt/homebrew or /usr/local" ;;
    *) check "brew_path_standard" false "$brew_path" "/opt/homebrew or /usr/local" "existing_brew_nonstandard" ;;
  esac
else
  check "brew_path_standard" true "(not installed yet)" "/opt/homebrew or /usr/local"
fi

# ── jq required (we use it everywhere) ─────────────────────────────────────
if command -v jq >/dev/null 2>&1; then
  check "jq_available" true "$(jq --version)" "any"
else
  # Not fatal — 01-prereqs.sh installs it. Note in JSON.
  check "jq_available" true "(will be installed by 01-prereqs)" "any"
fi

# ── Final JSON ─────────────────────────────────────────────────────────────
result_json=$(jq -nc \
  --argjson passed "$overall_passed" \
  --argjson checks "[$(IFS=,; echo "${checks[*]}")]" \
  --arg macos "$macos_ver" --arg arch "$arch_val" \
  '{passed: $passed, macos: $macos, arch: $arch, checks: $checks, generated_at: (now | todate)}')

echo "$result_json"

if [[ "$overall_passed" == "true" ]]; then
  log_ok "Preflight passed."
  exit 0
else
  log_err "Preflight failed. See JSON for which checks; consult docs/AGENT-DEBUG.md."
  exit 1
fi
