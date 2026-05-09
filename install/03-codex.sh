#!/usr/bin/env bash
# 03-codex.sh — Install OpenAI Codex CLI globally via npm.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

if have_cmd codex; then
  log_skip "codex already installed: $(codex --version 2>/dev/null || echo 'unknown version')"
else
  log "npm install -g @openai/codex"
  npm install -g @openai/codex
  log_ok "Codex CLI installed: $(codex --version 2>/dev/null || echo 'verify with: codex --version')"
fi

ensure_dir "$CODEX_DIR"

EXAMPLE="$CONFIG_DIR/codex-config.example.json"
TARGET="$CODEX_DIR/config.json"
if [[ -f "$TARGET" ]]; then
  log_skip "$TARGET already exists — leaving in place"
else
  if [[ -f "$EXAMPLE" ]]; then
    cp "$EXAMPLE" "$TARGET"
    log_ok "Wrote example $TARGET"
  fi
fi

# OpenAI API key check — don't write the key, just check it's set.
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  log_ok "OPENAI_API_KEY is set in environment"
else
  cat <<EOF

  ${C_YELLOW}OPENAI_API_KEY is not set.${C_RESET}

  Codex needs an OpenAI API key. Two options:

    1. Run \`codex login\` — opens a browser for OAuth (recommended).

    2. Set the env var manually:
       echo 'export OPENAI_API_KEY=sk-...' >> ~/.zprofile

  Hermes (next step) reads the same key from \$HERMES_DIR/.env.

EOF
fi
