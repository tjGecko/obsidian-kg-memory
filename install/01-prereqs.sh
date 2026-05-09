#!/usr/bin/env bash
# 01-prereqs.sh — Install Homebrew, Node 20, Python 3.11, git, jq.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

STEP_NAME="01-prereqs"
step_start
step_trap_err

# ── Homebrew ───────────────────────────────────────────────────────────────
if have_cmd brew; then
  log_skip "Homebrew already installed"
else
  log "Installing Homebrew (will require sudo password)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for the current shell and future shells.
  if [[ "$(arch)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
  else
    BREW_PREFIX="/usr/local"
  fi
  eval "$(${BREW_PREFIX}/bin/brew shellenv)"

  # Persist for zsh (default on modern macOS) and bash.
  for rc in "$HOME/.zprofile" "$HOME/.bash_profile"; do
    if ! grep -q 'brew shellenv' "$rc" 2>/dev/null; then
      echo "eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\"" >> "$rc"
    fi
  done
  log_ok "Homebrew installed and added to PATH"
fi

# ── Xcode CLT (required by many brew packages) ─────────────────────────────
if xcode-select -p >/dev/null 2>&1; then
  log_skip "Xcode Command Line Tools already installed"
else
  log "Installing Xcode Command Line Tools (a GUI dialog will appear)"
  xcode-select --install || true
  log "Waiting for Xcode CLT install to finish — re-run this script if it doesn't complete in time"
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  log_ok "Xcode CLT ready"
fi

# ── jq, git ────────────────────────────────────────────────────────────────
for pkg in git jq; do
  if have_cmd "$pkg"; then
    log_skip "$pkg already installed"
  else
    log "brew install $pkg"
    brew install "$pkg"
  fi
done

# ── Node 20 LTS ────────────────────────────────────────────────────────────
if have_cmd node && [[ "$(node -v)" == v20.* || "$(node -v)" == v22.* ]]; then
  log_skip "Node $(node -v) already installed"
else
  log "Installing node@20"
  brew install node@20
  brew link --overwrite --force node@20
  log_ok "Node $(node -v) installed"
fi

# Set up an npm global prefix that doesn't need sudo.
NPM_GLOBAL="$HOME/.npm-global"
ensure_dir "$NPM_GLOBAL"
npm config set prefix "$NPM_GLOBAL"
for rc in "$HOME/.zprofile" "$HOME/.bash_profile"; do
  if ! grep -q 'npm-global/bin' "$rc" 2>/dev/null; then
    echo "export PATH=\"\$HOME/.npm-global/bin:\$PATH\"" >> "$rc"
  fi
done
export PATH="$HOME/.npm-global/bin:$PATH"
log_ok "npm global prefix → $NPM_GLOBAL"

# ── Python 3.11 + pipx ─────────────────────────────────────────────────────
if have_cmd python3.11; then
  log_skip "python3.11 already installed"
else
  log "Installing python@3.11"
  brew install python@3.11
fi

if have_cmd pipx; then
  log_skip "pipx already installed"
else
  log "brew install pipx"
  brew install pipx
  pipx ensurepath || true
fi

log_ok "Prereqs complete"

step_complete "$(jq -nc \
  --arg node "$(node -v 2>/dev/null || echo "")" \
  --arg python "$(python3.11 --version 2>/dev/null || echo "")" \
  --arg brew "$(brew --version 2>/dev/null | head -1 || echo "")" \
  '{node: $node, python: $python, brew: $brew, installed: true}')"
