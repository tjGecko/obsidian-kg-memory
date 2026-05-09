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

export REPO_ROOT INSTALL_DIR SKILLS_DIR CONFIG_DIR KG_VAULT CLAUDE_DIR CLAUDE_SKILLS HERMES_DIR CODEX_DIR
