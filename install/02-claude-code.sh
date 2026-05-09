#!/usr/bin/env bash
# 02-claude-code.sh — Install Claude Code CLI globally via npm.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

STEP_NAME="02-claude-code"
step_start
step_trap_err

if have_cmd claude; then
  log_skip "claude already installed: $(claude --version 2>/dev/null || echo 'unknown version')"
else
  STEP_ERROR_CODE="npm_install_fail"
  log "npm install -g @anthropic-ai/claude-code"
  npm install -g @anthropic-ai/claude-code
  log_ok "Claude Code installed: $(claude --version 2>/dev/null || echo 'verify with: claude --version')"
  STEP_ERROR_CODE=""
fi

# Ensure ~/.claude exists for skills + settings.
ensure_dir "$CLAUDE_DIR"
ensure_dir "$CLAUDE_SKILLS"

# Drop an example settings file (won't overwrite existing).
EXAMPLE="$CONFIG_DIR/claude-settings.example.json"
TARGET="$CLAUDE_DIR/settings.json"
if [[ -f "$TARGET" ]]; then
  log_skip "$TARGET already exists — leaving in place"
else
  if [[ -f "$EXAMPLE" ]]; then
    cp "$EXAMPLE" "$TARGET"
    log_ok "Wrote example $TARGET"
  else
    log_warn "No example settings file found at $EXAMPLE — skipping"
  fi
fi

cat <<EOF

  Claude Code is installed but not yet authenticated.
  On first run you'll be prompted to log in to your Anthropic account.

  To start: run \`claude\` in any directory.

EOF

step_complete "$(jq -nc \
  --arg version "$(claude --version 2>/dev/null || echo "")" \
  --arg path "$(command -v claude || echo "")" \
  '{installed: true, version: $version, path: $path}')"
