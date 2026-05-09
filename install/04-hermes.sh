#!/usr/bin/env bash
# 04-hermes.sh — Install the Hermes Agent (NousResearch) via the official one-liner,
# then drop our example config wired to the OpenAI Codex provider with gpt-5.5.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

if have_cmd hermes; then
  log_skip "hermes already installed: $(hermes --version 2>/dev/null | head -1 || echo 'unknown version')"
else
  log "Installing Hermes Agent from NousResearch (official one-liner)"
  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

  # The Hermes installer writes to ~/.local/bin — ensure it's on PATH.
  for rc in "$HOME/.zprofile" "$HOME/.bash_profile"; do
    if ! grep -q '.local/bin' "$rc" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    fi
  done
  export PATH="$HOME/.local/bin:$PATH"

  if have_cmd hermes; then
    log_ok "Hermes installed: $(hermes --version 2>/dev/null | head -1)"
  else
    log_err "Hermes install completed but \`hermes\` not on PATH. Open a new terminal and re-run."
    exit 1
  fi
fi

ensure_dir "$HERMES_DIR"

# Drop our example config (won't overwrite existing).
EXAMPLE="$CONFIG_DIR/hermes-config.example.yaml"
TARGET="$HERMES_DIR/config.yaml"
if [[ -f "$TARGET" ]]; then
  log_skip "$TARGET already exists — leaving in place"
else
  if [[ -f "$EXAMPLE" ]]; then
    cp "$EXAMPLE" "$TARGET"
    log_ok "Wrote example $TARGET (model.default: gpt-5.5, provider: openai-codex)"
  else
    log_warn "No example config found at $EXAMPLE"
  fi
fi

# .env stub — never overwrite if it exists; just ensure presence with placeholder.
ENV_FILE="$HERMES_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  log_skip "$ENV_FILE already exists — leaving in place"
else
  cat > "$ENV_FILE" <<'EOF'
# Hermes Agent secrets — never commit this file.
# Add your OpenAI API key below:
OPENAI_API_KEY=
EOF
  chmod 600 "$ENV_FILE"
  log_ok "Stubbed $ENV_FILE (chmod 600). Edit it and add your OPENAI_API_KEY."
fi

cat <<EOF

  Hermes installed. To finish setup:

    1. Edit $HERMES_DIR/.env and add your OPENAI_API_KEY.
    2. Run: hermes setup    # to verify the config
    3. Run: hermes          # to start a session

EOF
