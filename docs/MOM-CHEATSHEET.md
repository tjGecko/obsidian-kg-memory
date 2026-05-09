# Daily Use — Plain-English Cheatsheet

This is a one-page guide to using the system day-to-day. No technical jargon. If something here doesn't match what you're seeing on screen, ask whoever set this up for you.

## What's on your Mac

You have four new things:

| Thing | What it does | How you use it |
|---|---|---|
| **Aqua Voice** | Listens when you speak and types it out. | Press your hotkey, talk, release. |
| **Claude Code** | An AI assistant in the Terminal app. Best for keeping notes and answering "what did I save about..." questions. | Open Terminal, type `claude`, press Enter. |
| **Hermes** | A second AI assistant, also in Terminal. Different brain — good for help with everyday questions, writing, drafting messages. | Open Terminal, type `hermes`, press Enter. |
| **Obsidian** | A notebook app. This is where your saved notes actually live. | Click the Obsidian icon in your dock. |

You don't need to learn all four at once. Start with **Aqua Voice + Claude Code**.

## The basics

### To save a thought

1. Open Terminal (it's in Applications → Utilities, or press ⌘+Space and type "terminal").
2. Type `claude` and press Enter.
3. Press the Aqua Voice hotkey and say:
   > "Save a note: chickadees only show up at the bird feeder around sunrise."
4. Release the hotkey. Words appear in the terminal.
5. Press Enter. Claude Code files the note in your notebook (Obsidian).

That's it. The note is now searchable forever.

### To ask "what did I save about...?"

In the same Claude Code window:

1. Press the Aqua Voice hotkey.
2. Say: "What have I saved about the bird feeder?"
3. Release. Press Enter.
4. Claude Code reads your notes and tells you.

### To save an article you read online

1. Copy the article URL from your browser.
2. In Claude Code, paste it and add: "save this".
3. Press Enter. Claude Code reads the page, summarizes the key points, and files it.

### To browse your saved stuff

1. Click the Obsidian icon in the dock.
2. The left sidebar shows folders: `kg/notes/`, `kg/sources/`, `kg/topics/`.
3. Click any file to read it. Click `_dashboard.md` for a tidy overview.

### To get general help (writing, ideas, drafting)

Use Hermes instead of Claude Code:

1. Open a new Terminal window.
2. Type `hermes` and press Enter.
3. Press the Aqua Voice hotkey and say what you need.

Hermes uses a different AI (GPT-5.5) so it has a different style. Claude Code is your "memory keeper". Hermes is your "general helper".

## Things to know

- **You don't have to spell anything right when speaking.** Aqua Voice is good at proper names.
- **You can talk in long sentences.** No need to clip your speech.
- **Nothing is ever lost.** Every saved note is in the Obsidian vault. You can open them in any text editor — even TextEdit on your Mac.
- **You can edit notes by hand in Obsidian.** Just click and type.

## When something looks wrong

Ask the person who set this up for you. They have a screen they can share with your computer remotely (with your permission) — they can see what you see and fix it together.

If you want to try one thing first: close the Terminal window completely (⌘+Q) and open a new one. Most "stuck" issues clear up that way.

## Quick reference

| You want to... | Type this in Claude Code |
|---|---|
| Save a thought | `/kg-add-note "your thought here"` (or just paste it and ask Claude to save it) |
| Save an article | `/kg-add-source <url>` |
| Find something you saved | `/kg-query what I saved about <topic>` |
| Tidy up the notebook | `/kg-update` |

You don't have to memorize the slash commands — you can also just describe what you want in plain English and Claude Code will figure it out.
