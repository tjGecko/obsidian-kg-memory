#!/usr/bin/env bash
# Shared helpers sourced by every install step.
# Logging, idempotency checks, prompt utilities.

set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m';  C_DIM=$'\033[2m';     C_RESET=$'\033[0m'
else
  C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_RESET=""
fi

log()       { printf "%s==>%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
log_ok()    { printf "%s ✓%s %s\n"  "$C_GREEN"  "$C_RESET" "$*"; }
log_warn()  { printf "%s ⚠%s %s\n"  "$C_YELLOW" "$C_RESET" "$*"; }
log_err()   { printf "%s ✗%s %s\n"  "$C_RED"    "$C_RESET" "$*" >&2; }
log_skip()  { printf "%s ·%s %s (skipped)\n" "$C_DIM" "$C_RESET" "$*"; }

# ── Platform check ─────────────────────────────────────────────────────────
require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_err "This installer is macOS-only. For other platforms see docs/MANUAL-INSTALL.md."
    exit 1
  fi
}

arch() { uname -m; }   # arm64 | x86_64

# ── Idempotency helpers ────────────────────────────────────────────────────
have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_dir() { [[ -d "$1" ]] || mkdir -p "$1"; }

# ── Prompts ────────────────────────────────────────────────────────────────
confirm() {
  # confirm "Proceed?" → returns 0 if yes, 1 if no. Defaults to yes on ENTER.
  local prompt="${1:-Proceed?}"
  printf "%s [Y/n] " "$prompt"
  read -r reply
  [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

prompt_secret() {
  # prompt_secret "OpenAI API key: " → echoes the value with no terminal echo.
  local prompt="$1"
  local val
  printf "%s" "$prompt" >&2
  IFS= read -rs val
  printf "\n" >&2
  printf "%s" "$val"
}

# ── Repo paths ─────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="$REPO_ROOT/install"
SKILLS_DIR="$REPO_ROOT/skills"
CONFIG_DIR="$REPO_ROOT/config"

# ── User paths ─────────────────────────────────────────────────────────────
KG_VAULT="${KG_VAULT:-$HOME/Documents/KG-Vault}"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS="$CLAUDE_DIR/skills"
HERMES_DIR="$HOME/.hermes"
CODEX_DIR="$HOME/.codex"

# ── State directory for per-step JSON status emission ──────────────────────
STATE_DIR="$INSTALL_DIR/.state"
ensure_dir "$STATE_DIR"

# Each step sets these before calling step_start.
STEP_NAME="${STEP_NAME:-unnamed}"
STEP_ERROR_CODE=""

# RFC 3339 / ISO 8601 timestamp.
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# step_start: write a "started" status JSON. Call at top of each step script.
# Usage: STEP_NAME="04-hermes" step_start
step_start() {
  STEP_STARTED_AT="$(now_iso)"
  STEP_STARTED_EPOCH="$(date +%s)"
  jq -nc \
    --arg step "$STEP_NAME" \
    --arg status "started" \
    --arg started "$STEP_STARTED_AT" \
    '{step: $step, status: $status, started_at: $started}' \
    > "$STATE_DIR/${STEP_NAME}.json"
}

# step_complete: write a "completed" status JSON. Call at end of each step.
# Usage: step_complete '{"installed": true, "version": "0.12.0"}'
step_complete() {
  local result_json="${1:-{}}"
  local finished_at="$(now_iso)"
  local duration=$(( $(date +%s) - ${STEP_STARTED_EPOCH:-$(date +%s)} ))
  jq -nc \
    --arg step "$STEP_NAME" \
    --arg status "completed" \
    --arg started "${STEP_STARTED_AT:-$finished_at}" \
    --arg finished "$finished_at" \
    --argjson duration "$duration" \
    --argjson result "$result_json" \
    '{step: $step, status: $status, started_at: $started, finished_at: $finished,
      duration_seconds: $duration, result: $result, error: null}' \
    > "$STATE_DIR/${STEP_NAME}.json"
}

# step_skip: write a "skipped" status JSON.
# Usage: step_skip "already installed"
step_skip() {
  local reason="${1:-not specified}"
  local finished_at="$(now_iso)"
  jq -nc \
    --arg step "$STEP_NAME" \
    --arg status "skipped" \
    --arg started "${STEP_STARTED_AT:-$finished_at}" \
    --arg finished "$finished_at" \
    --arg reason "$reason" \
    '{step: $step, status: $status, started_at: $started, finished_at: $finished,
      duration_seconds: 0, result: {skipped_reason: $reason}, error: null}' \
    > "$STATE_DIR/${STEP_NAME}.json"
}

# step_fail: write a "failed" status JSON. Called by the ERR trap.
# Usage: step_fail <error_code> <message> [recovery_hint]
step_fail() {
  local code="${1:-unknown}"
  local msg="${2:-(no message)}"
  local hint="${3:-See docs/AGENT-DEBUG.md}"
  local finished_at="$(now_iso)"
  local duration=$(( $(date +%s) - ${STEP_STARTED_EPOCH:-$(date +%s)} ))
  jq -nc \
    --arg step "$STEP_NAME" \
    --arg status "failed" \
    --arg started "${STEP_STARTED_AT:-$finished_at}" \
    --arg finished "$finished_at" \
    --argjson duration "$duration" \
    --arg code "$code" --arg msg "$msg" --arg hint "$hint" \
    '{step: $step, status: $status, started_at: $started, finished_at: $finished,
      duration_seconds: $duration, result: null,
      error: {code: $code, message: $msg, recovery_hint: $hint}}' \
    > "$STATE_DIR/${STEP_NAME}.json"
}

# step_trap_err: install an ERR trap that calls step_fail with the current STEP_ERROR_CODE.
# Call once at the top of each step, after step_start.
step_trap_err() {
  trap 'rc=$?; step_fail "${STEP_ERROR_CODE:-unknown}" "Step ${STEP_NAME} failed at: ${BASH_COMMAND} (exit $rc)" "Re-run install/${STEP_NAME}.sh after addressing the error"' ERR
}

export REPO_ROOT INSTALL_DIR SKILLS_DIR CONFIG_DIR KG_VAULT CLAUDE_DIR CLAUDE_SKILLS HERMES_DIR CODEX_DIR STATE_DIR
