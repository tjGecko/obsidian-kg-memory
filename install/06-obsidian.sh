#!/usr/bin/env bash
# 06-obsidian.sh — Install Obsidian via Homebrew cask, create the KG vault,
# and pre-install the Dataview community plugin.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

STEP_NAME="06-obsidian"
step_start
step_trap_err

# ── Obsidian app ───────────────────────────────────────────────────────────
if [[ -d "/Applications/Obsidian.app" ]]; then
  log_skip "Obsidian already installed"
else
  log "brew install --cask obsidian"
  brew install --cask obsidian
  log_ok "Obsidian installed"
fi

# ── Create the vault directory ─────────────────────────────────────────────
ensure_dir "$KG_VAULT"
ensure_dir "$KG_VAULT/.obsidian"
ensure_dir "$KG_VAULT/.obsidian/plugins"

# Mark this directory as an Obsidian vault by writing app.json if missing.
APP_JSON="$KG_VAULT/.obsidian/app.json"
if [[ ! -f "$APP_JSON" ]]; then
  cat > "$APP_JSON" <<'EOF'
{
  "alwaysUpdateLinks": true,
  "useMarkdownLinks": false,
  "newLinkFormat": "shortest",
  "attachmentFolderPath": "kg/_attachments"
}
EOF
  log_ok "Initialized Obsidian vault at $KG_VAULT"
else
  log_skip "$APP_JSON already exists"
fi

# Register the vault with Obsidian's vault registry so it appears in the picker.
OBSIDIAN_CONFIG="$HOME/Library/Application Support/obsidian/obsidian.json"
ensure_dir "$(dirname "$OBSIDIAN_CONFIG")"
if [[ -f "$OBSIDIAN_CONFIG" ]] && have_cmd jq; then
  VAULT_HASH="$(echo -n "$KG_VAULT" | shasum -a 256 | cut -c1-16)"
  if ! jq -e --arg h "$VAULT_HASH" '.vaults[$h]' "$OBSIDIAN_CONFIG" >/dev/null 2>&1; then
    TS_MS=$(($(date +%s) * 1000))
    TMP="$(mktemp)"
    jq --arg h "$VAULT_HASH" --arg path "$KG_VAULT" --argjson ts "$TS_MS" \
      '.vaults[$h] = { "path": $path, "ts": $ts, "open": true }' \
      "$OBSIDIAN_CONFIG" > "$TMP"
    mv "$TMP" "$OBSIDIAN_CONFIG"
    log_ok "Registered vault with Obsidian"
  else
    log_skip "Vault already registered with Obsidian"
  fi
else
  log_warn "Obsidian config not found yet — open Obsidian once, then re-run this step to register the vault automatically. Or pick the vault manually: $KG_VAULT"
fi

# ── Pre-install Dataview ──────────────────────────────────────────────────
DATAVIEW_DIR="$KG_VAULT/.obsidian/plugins/dataview"
if [[ -f "$DATAVIEW_DIR/main.js" ]]; then
  log_skip "Dataview plugin already installed"
else
  log "Downloading Dataview plugin (latest GitHub release)"
  ensure_dir "$DATAVIEW_DIR"

  # Get latest release URLs from GitHub
  RELEASE_JSON=$(curl -fsSL https://api.github.com/repos/blacksmithgu/obsidian-dataview/releases/latest)
  for asset in main.js manifest.json styles.css; do
    URL=$(echo "$RELEASE_JSON" | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url')
    if [[ -z "$URL" || "$URL" == "null" ]]; then
      log_warn "Could not find $asset in latest Dataview release; skipping"
      continue
    fi
    curl -fsSL -o "$DATAVIEW_DIR/$asset" "$URL"
  done

  # Mark as enabled in community-plugins.json.
  CP_FILE="$KG_VAULT/.obsidian/community-plugins.json"
  if [[ -f "$CP_FILE" ]]; then
    if ! grep -q '"dataview"' "$CP_FILE"; then
      jq '. + ["dataview"]' "$CP_FILE" > "$CP_FILE.tmp" && mv "$CP_FILE.tmp" "$CP_FILE"
    fi
  else
    echo '["dataview"]' > "$CP_FILE"
  fi

  log_ok "Dataview plugin installed at $DATAVIEW_DIR"
fi

cat <<EOF

  Obsidian + Dataview ready.
  Vault path: $KG_VAULT

  Open Obsidian and select this vault. Trust the plugin when prompted.

EOF

step_complete "$(jq -nc \
  --arg vault "$KG_VAULT" \
  --argjson dataview_installed "$([[ -f "$KG_VAULT/.obsidian/plugins/dataview/main.js" ]] && echo true || echo false)" \
  '{installed: true, vault: $vault, dataview_installed: $dataview_installed}')"
