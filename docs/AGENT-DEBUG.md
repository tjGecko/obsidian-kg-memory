# Agent Debugging Reference

Failure-mode → recovery table for autonomous agents running the installer. The first column is the `error.code` value emitted in step status JSON.

## How to use this document

When a step fails, its status JSON contains `error.code`. Look that code up here. Each entry tells you:
- **What it means** — the underlying cause
- **Auto-recover** — commands you can run without human help
- **Escalate** — when to give up and ask the human

If a code appears in a step status but isn't in this table, treat as `unknown` and follow the [Unknown errors](#unknown-errors) section.

## Preflight error codes

### `macos_too_old`
- **Means:** macOS version is below 13.0 (Ventura).
- **Auto-recover:** None. Apple-supported upgrade only.
- **Escalate:** Yes. Tell the human to update macOS via System Settings → General → Software Update before re-running.

### `arch_unsupported`
- **Means:** `uname -m` returned something other than `arm64` or `x86_64` (very unlikely).
- **Auto-recover:** None.
- **Escalate:** Yes. Likely a virtualized environment with an unusual config.

### `disk_low`
- **Means:** Less than 10 GB free on the boot volume.
- **Auto-recover:** None — don't auto-delete user files.
- **Escalate:** Yes. Tell the human to free space and re-run.

### `network_unreachable`
- **Means:** One of brew/npm/github/openai/aquavoice endpoints failed reachability.
- **Auto-recover:** Wait 30s and retry once. If still failing, escalate.
- **Escalate:** Yes. Likely captive portal, firewall, or DNS issue.

### `not_admin`
- **Means:** Current user lacks admin rights (cannot sudo even with password).
- **Auto-recover:** None.
- **Escalate:** Yes. Need an admin to either grant rights or run install on user's behalf.

### `existing_brew_nonstandard`
- **Means:** Homebrew installed at a non-standard path (not `/opt/homebrew` or `/usr/local`).
- **Auto-recover:** Try sourcing brew shellenv from the discovered path; if commands work, continue.
- **Escalate:** Only if commands still fail.

## Step-specific error codes

### `01-prereqs:brew_install_fail`
- **Means:** Homebrew installer exit code non-zero.
- **Auto-recover:** Re-run `01-prereqs.sh` once after waiting 60s (often a transient network issue).
- **Escalate:** If second attempt fails, copy the brew install log (`/tmp/brew-install.log` if present) to context and ask human.

### `01-prereqs:xcode_clt_pending`
- **Means:** `xcode-select --install` is showing a GUI dialog the user hasn't clicked yet.
- **Auto-recover:** Poll `xcode-select -p` every 30s for up to 15 min.
- **Escalate:** After 15 min, ask human if they saw the dialog.

### `01-prereqs:node_version_mismatch`
- **Means:** Node is installed but at a version we don't support (<20).
- **Auto-recover:** `brew unlink node && brew install node@20 && brew link --overwrite --force node@20`.
- **Escalate:** Only if `brew unlink` fails.

### `01.5-touchid:no_touch_id_hardware`
- **Means:** Machine has no Touch ID sensor.
- **Auto-recover:** Skip this step. Continue install (sudo will prompt for password each time, but this is non-fatal).
- **Escalate:** No.

### `01.5-touchid:pam_already_configured`
- **Means:** `pam_tid.so` line already in `/etc/pam.d/sudo`.
- **Auto-recover:** Treat as `completed`. No action.
- **Escalate:** No.

### `01.5-touchid:pam_edit_failed`
- **Means:** Could not write to `/etc/pam.d/sudo`.
- **Auto-recover:** Restore from backup (`/etc/pam.d/sudo.kgmem-bak`) if it exists. Skip touch-id step.
- **Escalate:** Yes if backup restore fails — sudo may be broken.

### `02-claude-code:npm_install_fail`
- **Means:** `npm install -g @anthropic-ai/claude-code` exit non-zero.
- **Auto-recover:** Check `npm config get prefix` is `~/.npm-global`; if not, run `npm config set prefix ~/.npm-global` then retry.
- **Escalate:** If retry fails, capture `npm-debug.log` and ask human.

### `03-codex:no_openai_key`
- **Means:** `OPENAI_API_KEY` not in env and `~/.codex/auth.json` missing.
- **Auto-recover:** Skip the key-check (Codex still installs; just won't run until key is set). Mark step as `completed` with a `next_human_action` note.
- **Escalate:** No — let user OAuth on first `codex` run.

### `04-hermes:install_script_fail`
- **Means:** The Hermes one-liner installer exited non-zero.
- **Auto-recover:** Check Python 3.11 is on PATH (`python3.11 --version`); if missing, re-run `01-prereqs.sh`. Then retry Hermes install.
- **Escalate:** If second retry fails, capture install log from `~/.hermes/install.log` (if present).

### `04-hermes:not_on_path`
- **Means:** Install completed but `which hermes` returns nothing.
- **Auto-recover:** Add `export PATH="$HOME/.local/bin:$PATH"` to `~/.zprofile` and source it. Re-test.
- **Escalate:** If still missing, the install location may have changed — ask human.

### `05-aqua-voice:download_fail`
- **Means:** `.dmg` download from S3 failed (HTTP error or timeout).
- **Auto-recover:** Retry once with 60s backoff.
- **Escalate:** If retry fails, S3 endpoint may be down or arch URL changed; ask human to download manually.

### `05-aqua-voice:dmg_mount_fail`
- **Means:** `hdiutil attach` failed.
- **Auto-recover:** Verify the `.dmg` file size is reasonable (>50 MB); if too small, the download was truncated — re-download.
- **Escalate:** If file is correct size but mount still fails, ask human (corrupted download is rare; usually a macOS issue).

### `05-aqua-voice:already_running`
- **Means:** `Aqua Voice.app` is in `/Applications` and currently running.
- **Auto-recover:** Use `osascript -e 'quit app "Aqua Voice"'` to quit, wait 5s, then re-attempt copy.
- **Escalate:** If quit fails, ask human to quit Aqua Voice manually.

### `06-obsidian:dataview_release_unparseable`
- **Means:** GitHub API returned a release JSON we couldn't parse for `main.js` URL.
- **Auto-recover:** Fall back to a hardcoded version from `install/versions.env` (`DATAVIEW_VERSION`).
- **Escalate:** Only if hardcoded version download also fails.

### `06-obsidian:vault_register_fail`
- **Means:** Could not write to `~/Library/Application Support/obsidian/obsidian.json`.
- **Auto-recover:** Skip vault registration. Vault still works; user just has to pick it manually first time.
- **Escalate:** No.

### `07-kg-init:vault_path_invalid`
- **Means:** `$KG_VAULT` doesn't exist and parent isn't writable.
- **Auto-recover:** Try default `~/Documents/KG-Vault`; if `~/Documents` doesn't exist, create it.
- **Escalate:** If default also fails, ask human for a writable vault path.

### `07-kg-init:skill_copy_fail`
- **Means:** Could not copy `skills/kg-memory/` into `~/.claude/skills/`.
- **Auto-recover:** Verify `~/.claude/` exists and is writable. If not, `mkdir -p ~/.claude/skills`.
- **Escalate:** Only if mkdir also fails.

### `08-verify:component_missing`
- **Means:** A check failed. Verify output names which.
- **Auto-recover:** Re-run the corresponding numbered install script.
- **Escalate:** If re-run also fails, drop into the matching step's debug section above.

### `09-permissions:user_did_not_grant`
- **Means:** User skipped or denied a permission grant.
- **Auto-recover:** None — Aqua Voice will not function without these. Re-run `09-permissions.sh` to retry.
- **Escalate:** Yes. Explain the consequence: speech-to-text will fail.

## Sudo / Touch ID quick recovery

If `01.5-touchid-sudo.sh` corrupted `/etc/pam.d/sudo` (sudo refuses to run):

1. Boot into Recovery (hold ⌘+R on Intel; press and hold power on Apple Silicon).
2. Open Terminal from Utilities menu.
3. `mount -uw /Volumes/Macintosh\ HD`
4. `cp /Volumes/Macintosh\ HD/etc/pam.d/sudo.kgmem-bak /Volumes/Macintosh\ HD/etc/pam.d/sudo`
5. Reboot.

If you don't have the backup, the canonical good content of `/etc/pam.d/sudo` is:
```
# sudo: auth account password session
auth       sufficient     pam_smartcard.so
auth       required       pam_opendirectory.so
account    required       pam_permit.so
password   required       pam_deny.so
session    required       pam_permit.so
```

## Unknown errors

If you encounter an error code not listed here:

1. Read the full error message and stderr from the failed step.
2. Check if it matches a known pattern (network timeout, permission denied, command not found).
3. If it's plausibly transient, retry once with 60s backoff.
4. If it persists, mark the step as `failed`, write what you tried into the status JSON's `error.message`, and continue with downstream steps that don't depend on this one.
5. Report in your final summary that this step needs human attention.

Don't keep retrying the same step indefinitely. Two attempts max, then flag and move on.
