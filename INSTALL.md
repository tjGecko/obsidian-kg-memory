# Installation Guide (macOS)

The full stack installs in one command. The orchestrator script runs nine numbered steps; each one is also runnable individually if you need to redo or skip a step.

## One-liner

```bash
git clone https://github.com/tjGecko/obsidian-kg-memory.git ~/obsidian-kg-memory
cd ~/obsidian-kg-memory
./install/install-mac.sh
```

The script is idempotent — safe to re-run. It detects what's already installed and skips those steps.

## What runs, in order

| Step | Script | What it does |
|---|---|---|
| 0 | `install-mac.sh` | Orchestrator. Detects shell, sources steps in order, prints a summary. |
| 1 | `01-prereqs.sh` | Installs Homebrew (if missing), Xcode CLT, Node 20 LTS, Python 3.11, git, jq. |
| 2 | `02-claude-code.sh` | `npm install -g @anthropic-ai/claude-code` — installs Claude Code. |
| 3 | `03-codex.sh` | `npm install -g @openai/codex` — installs OpenAI Codex CLI. Prompts for `OPENAI_API_KEY` if not set. |
| 4 | `04-hermes.sh` | Runs the official Hermes one-liner installer from NousResearch. Wires Hermes to use the Codex provider with `gpt-5.5`. |
| 5 | `05-aqua-voice.sh` | Downloads the architecture-correct Aqua Voice `.dmg`, mounts, and copies to `/Applications`. Prompts user to grant Accessibility + Microphone permissions on first launch. |
| 6 | `06-obsidian.sh` | `brew install --cask obsidian`. Creates the vault at `~/Documents/KG-Vault` (configurable). Installs the Dataview community plugin. |
| 7 | `07-kg-init.sh` | Copies `skills/kg-memory/` to `~/.claude/skills/`, runs `/kg-init` to seed the vault, drops example config files into `~/.hermes/` and `~/.codex/`. |
| 8 | `08-verify.sh` | Sanity check — runs `claude --version`, `codex --version`, `hermes --version`, opens the vault, lists installed skills. |

## Running individual steps

Each script can be run on its own. They source `install/_common.sh` for shared helpers (logging, idempotency checks).

```bash
# Re-run just the Hermes step
./install/04-hermes.sh

# Just install Aqua Voice
./install/05-aqua-voice.sh

# Re-seed the KG vault (will not overwrite existing cards)
./install/07-kg-init.sh
```

## Configuration

After install, three example config files are placed for you to customize. None contain secrets.

| File | Customize |
|---|---|
| `~/.hermes/config.yaml` | Default model, reasoning effort, which auxiliary providers are auto vs. disabled |
| `~/.codex/config.json` | Codex CLI defaults |
| `~/.claude/settings.json` | Claude Code settings (skills location, permissions) |

API keys go in:
- `~/.hermes/.env` — `OPENAI_API_KEY=sk-...`
- `~/.codex/auth.json` — managed by `codex login`
- `~/.claude/.credentials.json` — managed by `claude` first-run

The installer never writes secrets — it only checks they exist and prompts you to add them.

## Uninstall

```bash
./install/uninstall-mac.sh
```

Removes Claude Code, Codex, Hermes, and Obsidian. Leaves the vault at `~/Documents/KG-Vault` (your data) and Aqua Voice (you may want it for other apps) untouched. Pass `--purge` to remove everything including the vault.

## Manual install reference

If a script fails or you want to install something by hand, see [`docs/MANUAL-INSTALL.md`](docs/MANUAL-INSTALL.md) for the underlying commands each script runs.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `command not found: brew` after step 1 | Open a new terminal — Homebrew adds itself to PATH but only for new shells |
| Aqua Voice doesn't transcribe | System Settings → Privacy & Security → Microphone + Accessibility → enable Aqua Voice |
| `hermes` says no API key | Add `OPENAI_API_KEY=sk-...` to `~/.hermes/.env`, then re-run `hermes setup` |
| Claude Code can't find skills | Check `~/.claude/skills/kg-memory/SKILL.md` exists; re-run `./install/07-kg-init.sh` |
| Dataview queries empty in Obsidian | Settings → Community plugins → Dataview → enable; reload vault |
