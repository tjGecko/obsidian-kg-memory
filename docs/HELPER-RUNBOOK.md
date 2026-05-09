# Helper Runbook — Setting Someone Up Remotely

This document is for the person who's helping a non-technical user (parent, sibling, friend) get the stack running and stay running. Assume they're on a Mac, you're on whatever, and you'll be guiding them mostly over the phone or video call.

## Phase 1 — Initial install (one-time, ~30 minutes)

Choose one of these depending on how comfortable they are with terminal commands:

### Option A — They run it themselves with you watching

Best when they've used Terminal before, or you're on a screen-share.

1. Have them open Terminal.app.
2. They paste:
   ```bash
   git clone https://github.com/tjGecko/obsidian-kg-memory.git ~/obsidian-kg-memory
   cd ~/obsidian-kg-memory
   ./install/install-mac.sh
   ```
3. Walk them through:
   - Granting Aqua Voice the Microphone + Accessibility + Input Monitoring permissions.
   - Opening Aqua Voice and signing in.
   - Adding their `OPENAI_API_KEY` to `~/.hermes/.env` (you can paste it for them via screen-share).
   - First `claude` run — Anthropic OAuth in the browser.
   - First Obsidian launch — picking the vault.
4. Run `./install/08-verify.sh` together. All ten checks should pass.

### Option B — You do it via SSH

Best when they're not comfortable with terminal at all.

1. Have them enable Remote Login: System Settings → General → Sharing → Remote Login → on. They give you the username and machine name shown there.
2. They open a Terminal once and run `ssh-keygen -t ed25519` (just press Enter at every prompt) — this is so they can authenticate to their own services later.
3. You SSH in: `ssh user@their-mac.local`
4. Run the same install commands as Option A, step 2.
5. **Stop at step 5 (Aqua Voice)** — that step needs the Mac's GUI to mount a `.dmg` and grant permissions. Walk them through that part live.

## Phase 2 — Pair-programming sessions (ongoing)

Once installed, the easiest way to help is to run Claude Code on their machine while sitting on a video call. Two ways:

### Approach 1 — Screen share + voice

- They open Claude Code.
- You see their screen via FaceTime / Zoom screen share.
- You tell them what to type, or they describe what they want and you suggest the prompt.
- Easy and casual. Works for almost anything.

### Approach 2 — SSH and run Claude Code on their machine remotely

- You SSH in.
- You run `tmux new -s help` (creates a shared session).
- They open a Terminal and run `tmux attach -t help` — now you're both in the same terminal.
- Either of you can type. They watch what you do; you can demo things and they can repeat.
- When done: `Ctrl-B` then `d` to detach, `tmux kill-session -t help` to clean up.

### Approach 3 — Claude Code share link (when available)

If you're using Claude Code's collaboration / share features (check the latest Claude Code docs for "share session" or "team mode"), follow those instructions to drop into their session as a co-pilot. This is the most polished UX once they have access.

## Phase 3 — Routine maintenance (monthly)

Things that should be checked every month or two. You can do these over SSH without bothering them.

### Update everything

```bash
ssh user@their-mac.local
cd ~/obsidian-kg-memory
git pull
./install/install-mac.sh    # idempotent — re-runs only what's stale
brew update && brew upgrade
npm update -g @anthropic-ai/claude-code @openai/codex
```

### Back up the vault

The vault is the only thing that matters. Everything else is reinstallable.

```bash
ssh user@their-mac.local "tar -czf - ~/Documents/KG-Vault" | \
  cat > ~/backups/kg-vault-$(date +%Y-%m-%d).tar.gz
```

If they have iCloud Drive / Backblaze / Time Machine running, the vault is also covered there — but a manual snapshot every few months is cheap insurance.

### Run KG health check

In a Claude Code session on their machine:

```
/kg-update
/kg-topics --report
```

You'll see if any topics have grown too broad or any have orphaned. Fix interactively or tell them what to do.

## Common issues and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Aqua Voice hotkey does nothing | Input Monitoring permission revoked | System Settings → Privacy & Security → Input Monitoring → toggle Aqua Voice off and back on |
| `claude: command not found` | npm-global PATH dropped | `source ~/.zprofile` then re-try; if still broken, `./install/02-claude-code.sh` |
| `hermes` says "no API key" | They edited `~/.hermes/.env` but kept it empty | Open the file, paste `OPENAI_API_KEY=sk-...`, save, retry |
| Obsidian shows empty Dashboard | Dataview plugin not enabled | Settings → Community plugins → enable Dataview → reload vault |
| Notes not appearing in `_index.md` | `kg-update` hasn't run since the last write | Have them run `/kg-update` in Claude Code |
| `claude` hangs at startup | Anthropic creds expired | `claude logout` then `claude` to re-OAuth |
| Hermes returns garbage / refuses | Model name mismatch in config | Edit `~/.hermes/config.yaml`, set `model.default: gpt-5.5`, restart hermes |

## Things to teach them (in order of importance)

1. **The Aqua Voice hotkey.** Once they trust it, everything else is downstream of being able to talk to the computer.
2. **`claude` to start a session, `Ctrl-D` to leave.** The two key Terminal incantations.
3. **`/kg-add-note` (or just speaking it).** Their primary capture verb.
4. **`/kg-query` (or asking a question).** Their primary recall verb.
5. **The Obsidian vault is just files.** Anything stored is theirs forever, in plain Markdown.

Skip teaching: shell paths, environment variables, what npm is, the difference between Claude and Hermes' underlying models. They don't need any of that.

## What to escalate vs. fix yourself

| Issue | Escalate (ask user) | Fix yourself (over SSH) |
|---|---|---|
| App won't open / crashes | ✓ — they need to click "Open Anyway" |  |
| Permission denied on mic/accessibility | ✓ — they have to grant in System Settings |  |
| Vault content edits | ✓ — never write into their notes without asking |  |
| Plugin install / config / state file fixes |  | ✓ |
| Topic dedup, broken link cleanup |  | ✓ — `/kg-update --dry-run` first, then apply |
| Model / version upgrades |  | ✓ |
| Backups |  | ✓ — but tell them you did it |

## Final note

The whole point of this setup is that they shouldn't have to think about any of it. Aim for: they speak, things get saved; they ask, things come back. If they're spending mental cycles on the tools, the tools are wrong — fix the tools, don't ask them to adapt.
