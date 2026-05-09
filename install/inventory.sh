#!/usr/bin/env bash
# inventory.sh — Read-only report of what's currently installed.
# Outputs JSON to stdout; nothing to stderr unless an internal error.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh" 2>/dev/null

KG_VAULT="${KG_VAULT:-$HOME/Documents/KG-Vault}"

# ── helpers ────────────────────────────────────────────────────────────────
component_json() {
  local name="$1" cmd="$2" version_args="${3:---version}"
  local installed=false version="" path=""
  if command -v "$cmd" >/dev/null 2>&1; then
    installed=true
    path="$(command -v "$cmd")"
    version="$($cmd $version_args 2>/dev/null | head -1 | tr -d '\r' | sed 's/"/\\"/g' || echo "")"
  fi
  jq -nc --arg name "$name" --argjson installed "$installed" \
        --arg version "$version" --arg path "$path" \
        '{name: $name, installed: $installed, version: $version, path: $path}'
}

app_json() {
  local name="$1" app_path="$2"
  local installed=false version=""
  if [[ -d "$app_path" ]]; then
    installed=true
    plist="$app_path/Contents/Info.plist"
    if [[ -f "$plist" ]]; then
      version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist" 2>/dev/null || echo "")
    fi
  fi
  jq -nc --arg name "$name" --argjson installed "$installed" \
        --arg version "$version" --arg path "$app_path" \
        '{name: $name, installed: $installed, version: $version, path: $path}'
}

# ── system ────────────────────────────────────────────────────────────────
macos_ver=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
arch_val="$(uname -m)"
free_gb=$(df -g / | awk 'NR==2 {print $4}')

# ── components ────────────────────────────────────────────────────────────
brew=$(component_json "homebrew" "brew" "--version")
node=$(component_json "node" "node" "--version")
npm=$(component_json "npm" "npm" "--version")
python=$(component_json "python3.11" "python3.11" "--version")
pipx=$(component_json "pipx" "pipx" "--version")
git=$(component_json "git" "git" "--version")
jq_=$(component_json "jq" "jq" "--version")
claude=$(component_json "claude-code" "claude" "--version")
codex=$(component_json "codex" "codex" "--version")
hermes=$(component_json "hermes" "hermes" "--version")

# ── apps ──────────────────────────────────────────────────────────────────
obsidian=$(app_json "obsidian" "/Applications/Obsidian.app")
aqua=$(app_json "aqua-voice" "/Applications/Aqua Voice.app")

# ── vault ─────────────────────────────────────────────────────────────────
vault_exists=false; kg_initialized=false; note_count=0; source_count=0; topic_count=0
if [[ -d "$KG_VAULT" ]]; then
  vault_exists=true
  if [[ -f "$KG_VAULT/kg/_index.md" ]]; then
    kg_initialized=true
    note_count=$(find "$KG_VAULT/kg/notes" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    source_count=$(find "$KG_VAULT/kg/sources" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    topic_count=$(find "$KG_VAULT/kg/topics" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  fi
fi
dataview_installed=false
[[ -f "$KG_VAULT/.obsidian/plugins/dataview/main.js" ]] && dataview_installed=true

vault=$(jq -nc \
  --arg path "$KG_VAULT" \
  --argjson exists "$vault_exists" --argjson kg_initialized "$kg_initialized" \
  --argjson notes "$note_count" --argjson sources "$source_count" --argjson topics "$topic_count" \
  --argjson dataview "$dataview_installed" \
  '{path: $path, exists: $exists, kg_initialized: $kg_initialized,
    notes: $notes, sources: $sources, topics: $topics,
    dataview_plugin_installed: $dataview}')

# ── skills ────────────────────────────────────────────────────────────────
skills_installed=false
[[ -f "$HOME/.claude/skills/kg-memory/SKILL.md" ]] && skills_installed=true

# ── credentials present? (boolean only — never read content) ───────────────
hermes_env=false; openai_in_env=false; claude_creds=false; codex_creds=false
[[ -s "$HOME/.hermes/.env" ]] && grep -q '^OPENAI_API_KEY=.\+' "$HOME/.hermes/.env" 2>/dev/null && hermes_env=true
[[ -n "${OPENAI_API_KEY:-}" ]] && openai_in_env=true
[[ -f "$HOME/.claude/.credentials.json" ]] && claude_creds=true
[[ -f "$HOME/.codex/auth.json" ]] && codex_creds=true

# ── permissions (best-effort detection) ────────────────────────────────────
# Touch ID for sudo: detectable via /etc/pam.d/sudo content.
touchid_sudo=false
if grep -q 'pam_tid.so' /etc/pam.d/sudo 2>/dev/null; then touchid_sudo=true; fi

# Aqua Voice TCC permissions: not directly readable on modern macOS without root + SIP off.
# We report them as "unknown" — the user is the source of truth.
aqua_mic="unknown"; aqua_a11y="unknown"; aqua_input="unknown"

permissions=$(jq -nc \
  --argjson touchid_sudo "$touchid_sudo" \
  --arg aqua_mic "$aqua_mic" --arg aqua_a11y "$aqua_a11y" --arg aqua_input "$aqua_input" \
  '{touchid_sudo: $touchid_sudo, aqua_voice_microphone: $aqua_mic,
    aqua_voice_accessibility: $aqua_a11y, aqua_voice_input_monitoring: $aqua_input}')

# ── Identify gaps for an agent to act on ───────────────────────────────────
gaps=()
[[ "$brew" == *'"installed":false'* ]]    && gaps+=('"homebrew"')
[[ "$node" == *'"installed":false'* ]]    && gaps+=('"node"')
[[ "$python" == *'"installed":false'* ]]  && gaps+=('"python3.11"')
[[ "$claude" == *'"installed":false'* ]]  && gaps+=('"claude-code"')
[[ "$codex" == *'"installed":false'* ]]   && gaps+=('"codex"')
[[ "$hermes" == *'"installed":false'* ]]  && gaps+=('"hermes"')
[[ "$obsidian" == *'"installed":false'* ]] && gaps+=('"obsidian"')
[[ "$aqua" == *'"installed":false'* ]]    && gaps+=('"aqua-voice"')
[[ "$skills_installed" == "false" ]]      && gaps+=('"kg-skills"')
[[ "$vault_exists" == "false" ]]          && gaps+=('"vault"')
[[ "$kg_initialized" == "false" ]]        && gaps+=('"kg-init"')
[[ "$dataview_installed" == "false" ]]    && gaps+=('"dataview-plugin"')
[[ "$hermes_env" == "false" && "$openai_in_env" == "false" ]] && gaps+=('"openai-api-key"')

gaps_json="[$(IFS=,; echo "${gaps[*]:-}")]"

# ── Final JSON ─────────────────────────────────────────────────────────────
jq -nc \
  --arg macos "$macos_ver" --arg arch "$arch_val" --argjson disk_free_gb "$free_gb" \
  --argjson brew "$brew" --argjson node "$node" --argjson npm "$npm" \
  --argjson python "$python" --argjson pipx "$pipx" --argjson git "$git" --argjson jq "$jq_" \
  --argjson claude "$claude" --argjson codex "$codex" --argjson hermes "$hermes" \
  --argjson obsidian "$obsidian" --argjson aqua "$aqua" \
  --argjson vault "$vault" --argjson permissions "$permissions" \
  --argjson skills_installed "$skills_installed" \
  --argjson hermes_env "$hermes_env" --argjson openai_in_env "$openai_in_env" \
  --argjson claude_creds "$claude_creds" --argjson codex_creds "$codex_creds" \
  --argjson gaps "$gaps_json" \
  '{
    system: {macos: $macos, arch: $arch, disk_free_gb: $disk_free_gb},
    components: {
      homebrew: $brew, node: $node, npm: $npm,
      python: $python, pipx: $pipx, git: $git, jq: $jq,
      claude_code: $claude, codex: $codex, hermes: $hermes
    },
    apps: {obsidian: $obsidian, aqua_voice: $aqua},
    vault: $vault,
    skills: {kg_memory_installed: $skills_installed},
    credentials: {
      openai_api_key_in_hermes_env: $hermes_env,
      openai_api_key_in_shell_env: $openai_in_env,
      claude_credentials_present: $claude_creds,
      codex_credentials_present: $codex_creds
    },
    permissions: $permissions,
    gaps: $gaps,
    generated_at: (now | todate)
  }'
