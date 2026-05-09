#!/usr/bin/env bash
# 01.5-touchid-sudo.sh — Enable Touch ID for sudo authentication.
#
# After this runs, every sudo prompt accepts a fingerprint instead of a password,
# eliminating ~80% of password prompts during install.
#
# Safety: backs up /etc/pam.d/sudo before editing. Idempotent — safe to re-run.
# If something goes wrong, follow recovery in docs/AGENT-DEBUG.md ("Sudo / Touch ID quick recovery").

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

STEP_NAME="01.5-touchid-sudo"
step_start
step_trap_err

PAM_FILE="/etc/pam.d/sudo"
PAM_BACKUP="/etc/pam.d/sudo.kgmem-bak"
PAM_LINE="auth       sufficient     pam_tid.so"

# ── Detect Touch ID hardware ──────────────────────────────────────────────
# bioutil reports biometric hardware status. Absence or "not supported" means no T.I.
if ! /usr/bin/bioutil -rs >/dev/null 2>&1; then
  log_warn "Touch ID hardware not detected on this Mac. Skipping (sudo will continue to prompt for password)."
  step_skip "no touch id hardware"
  exit 0
fi

# ── Already configured? ───────────────────────────────────────────────────
if grep -q 'pam_tid.so' "$PAM_FILE"; then
  log_skip "Touch ID for sudo already enabled in $PAM_FILE"
  step_skip "pam_tid.so already in $PAM_FILE"
  exit 0
fi

# ── Cache sudo credentials once ───────────────────────────────────────────
log "This step modifies $PAM_FILE — sudo password required once."
if ! sudo -v; then
  STEP_ERROR_CODE="sudo_auth_failed"
  log_err "Could not authenticate with sudo. Skipping Touch ID setup."
  exit 1
fi

# ── Backup the file ───────────────────────────────────────────────────────
if [[ ! -f "$PAM_BACKUP" ]]; then
  STEP_ERROR_CODE="pam_edit_failed"
  log "Backing up $PAM_FILE → $PAM_BACKUP"
  sudo cp "$PAM_FILE" "$PAM_BACKUP"
  sudo chmod 644 "$PAM_BACKUP"
  STEP_ERROR_CODE=""
else
  log_skip "Backup already exists at $PAM_BACKUP"
fi

# ── Insert pam_tid line at the top of the auth section ────────────────────
STEP_ERROR_CODE="pam_edit_failed"
TMP=$(mktemp)
sudo cat "$PAM_FILE" > "$TMP"

# The first non-comment line should be an "auth" line. Insert pam_tid above it.
awk -v line="$PAM_LINE" '
  BEGIN { inserted = 0 }
  !inserted && /^auth/ {
    print line
    inserted = 1
  }
  { print }
' "$TMP" | sudo tee "$PAM_FILE.new" >/dev/null

sudo mv "$PAM_FILE.new" "$PAM_FILE"
sudo chmod 644 "$PAM_FILE"
sudo chown root:wheel "$PAM_FILE"
rm -f "$TMP"
STEP_ERROR_CODE=""

# ── Validate the edit took ────────────────────────────────────────────────
if ! grep -q 'pam_tid.so' "$PAM_FILE"; then
  STEP_ERROR_CODE="pam_edit_failed"
  log_err "Edit appeared to succeed but pam_tid.so not found in $PAM_FILE. Restoring backup."
  sudo cp "$PAM_BACKUP" "$PAM_FILE"
  exit 1
fi

# ── Sanity check: sudo still works ────────────────────────────────────────
# (Calling `sudo -v` here will use the cached credential, not prompt.)
if ! sudo -nv 2>/dev/null; then
  STEP_ERROR_CODE="pam_edit_failed"
  log_err "Sudo no longer functioning after edit. Restoring backup immediately."
  sudo cp "$PAM_BACKUP" "$PAM_FILE"
  exit 1
fi

log_ok "Touch ID enabled for sudo. Next sudo prompt will accept your fingerprint."

step_complete "$(jq -nc \
  --arg pam_file "$PAM_FILE" --arg backup "$PAM_BACKUP" \
  '{enabled: true, pam_file: $pam_file, backup: $backup}')"
