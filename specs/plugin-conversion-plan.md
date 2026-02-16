# Plan: Convert Multi-Agent Observability to a Claude Code Plugin

## Overview

Convert this project from a `.claude/hooks`-based setup (tied to a single project) into a distributable Claude Code plugin that anyone can install via `/plugin install` to get full multi-agent observability in their own projects.

## Research Summary

### How Claude Code Plugins Work

Plugins are self-contained directories with a `.claude-plugin/plugin.json` manifest. Claude Code auto-discovers components from conventional directories:

| Directory | Purpose |
|-----------|---------|
| `.claude-plugin/plugin.json` | Required manifest (metadata only) |
| `hooks/hooks.json` | Hook event configuration |
| `commands/*.md` | Slash commands (namespaced as `/plugin-name:command`) |
| `agents/*.md` | Subagent definitions |
| `skills/*/SKILL.md` | Auto-invoked skills |
| `.mcp.json` | MCP server configs |

Key runtime variable: `${CLAUDE_PLUGIN_ROOT}` resolves to the plugin's installed root directory.

Plugins are distributed via **marketplaces** (Git repos with `.claude-plugin/marketplace.json`). Users install with:
```
/plugin marketplace add owner/marketplace-repo
/plugin install plugin-name@marketplace-name
```

For local development: `claude --plugin-dir ./my-plugin`

### Superpowers Plugin Pattern (Reference)

The superpowers plugin (29k+ stars) demonstrates best practices:
- **Minimal manifest**: `plugin.json` contains only metadata, no component listings
- **Convention-based discovery**: Components found by directory presence
- **Hook-based bootstrapping**: A `SessionStart` hook injects context via `hookSpecificOutput.additionalContext`
- **Shell scripts for hooks**: Uses `${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh`
- **Commands as skill dispatchers**: Each command is a thin wrapper invoking a skill
- **Separate marketplace repo**: Distribution via `obra/superpowers-marketplace`

---

## Current State

```
.claude/
├── settings.json          # Hook config (12 event types) + env + statusLine
├── hooks/                 # 14 Python scripts + utils/ + validators/
│   ├── send_event.py      # Universal event sender
│   ├── pre_tool_use.py    # Tool validation
│   ├── post_tool_use.py   # Result logging
│   ├── ...                # 9 more event scripts
│   ├── utils/             # Shared utilities (summarizer, model_extractor, llm/, tts/)
│   └── validators/        # Stop hook validators
├── commands/              # User-specific commands (worktrees, build, etc.)
├── agents/                # User-specific agents (builder, validator, etc.)
├── skills/                # User-specific skills (worktree, video, meta)
├── status_lines/          # Status line script
└── output-styles/         # Output formatting

apps/
├── server/                # Bun HTTP+WebSocket server (SQLite)
└── client/                # Vue 3 + Vite dashboard

scripts/
├── start-system.sh        # Start server + client
└── reset-system.sh        # Stop all processes
```

**Problem**: Everything is intertwined in `.claude/` — observability hooks live alongside the user's personal commands, agents, and skills. Path references use `$CLAUDE_PROJECT_DIR/.claude/hooks/`.

---

## Target State

```
claude-code-observability/              # Plugin root (distributable)
├── .claude-plugin/
│   ├── plugin.json                     # Plugin manifest
│   └── marketplace.json                # Dev marketplace definition
│
├── hooks/
│   ├── hooks.json                      # Hook configuration (all 12 event types)
│   └── scripts/                        # Python hook scripts
│       ├── send_event.py
│       ├── pre_tool_use.py
│       ├── post_tool_use.py
│       ├── post_tool_use_failure.py
│       ├── permission_request.py
│       ├── notification.py
│       ├── user_prompt_submit.py
│       ├── stop.py
│       ├── subagent_start.py
│       ├── subagent_stop.py
│       ├── pre_compact.py
│       ├── session_start.py
│       ├── session_end.py
│       ├── utils/                      # Shared utilities
│       │   ├── constants.py
│       │   ├── summarizer.py
│       │   ├── model_extractor.py
│       │   ├── hitl.py
│       │   ├── llm/
│       │   └── tts/
│       └── validators/
│           ├── validate_new_file.py
│           └── validate_file_contains.py
│
├── commands/
│   ├── start.md                        # /observability:start - Start the dashboard
│   ├── stop.md                         # /observability:stop - Stop the dashboard
│   ├── status.md                       # /observability:status - Check health
│   └── reset-db.md                     # /observability:reset-db - Clear event database
│
├── skills/
│   └── observability/
│       └── SKILL.md                    # Auto-invoked skill for observability context
│
├── apps/
│   ├── server/                         # Bun server (unchanged internally)
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── db.ts
│   │   │   ├── theme.ts
│   │   │   └── types.ts
│   │   └── package.json
│   └── client/                         # Vue client (unchanged internally)
│       ├── src/
│       ├── package.json
│       └── vite.config.ts
│
├── scripts/
│   ├── start-system.sh                 # Start server + client
│   ├── reset-system.sh                 # Stop all processes
│   └── ensure-deps.sh                  # Check/install bun + uv dependencies
│
├── justfile                            # Task runner (updated paths)
├── README.md
└── CLAUDE.md
```

**What stays in the user's `.claude/` directory (NOT in the plugin):**
- Personal commands (worktrees, build, plan_w_team, etc.)
- Personal agents (builder, validator, scout, etc.)
- Personal skills (worktree-manager, video-processor, meta-skill)
- Personal output-styles
- Personal status_lines

---

## Implementation Steps

### Phase 1: Create Plugin Manifest and Structure

#### Step 1.1: Create `.claude-plugin/plugin.json`
```json
{
  "name": "observability",
  "version": "1.0.0",
  "description": "Real-time multi-agent observability dashboard for Claude Code — tracks all 12 hook event types with live WebSocket streaming, session filtering, and interactive visualization",
  "author": {
    "name": "ehartye"
  },
  "homepage": "https://github.com/ehartye/claude-code-hooks-multi-agent-observability",
  "repository": "https://github.com/ehartye/claude-code-hooks-multi-agent-observability",
  "license": "MIT",
  "keywords": ["observability", "monitoring", "multi-agent", "dashboard", "hooks", "visualization"]
}
```

#### Step 1.2: Create `.claude-plugin/marketplace.json`
```json
{
  "name": "observability-dev",
  "description": "Development marketplace for Claude Code Multi-Agent Observability plugin",
  "owner": {
    "name": "ehartye"
  },
  "plugins": [
    {
      "name": "observability",
      "description": "Real-time multi-agent observability dashboard for Claude Code",
      "version": "1.0.0",
      "source": "./"
    }
  ]
}
```

### Phase 2: Restructure Hooks

#### Step 2.1: Move hook scripts from `.claude/hooks/` to `hooks/scripts/`

Move all 13 Python hook scripts + `utils/` + `validators/` directories to `hooks/scripts/`.

#### Step 2.2: Create `hooks/hooks.json`

Extract hook configuration from `.claude/settings.json` into `hooks/hooks.json`. All paths change from:
```
uv run $CLAUDE_PROJECT_DIR/.claude/hooks/<script>.py
```
to:
```
uv run ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/<script>.py
```

Full `hooks/hooks.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "uv run ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/pre_tool_use.py"
          },
          {
            "type": "command",
            "command": "uv run ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/send_event.py --source-app cc-observability --event-type PreToolUse --summarize"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "uv run ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/post_tool_use.py"
          },
          {
            "type": "command",
            "command": "uv run ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/send_event.py --source-app cc-observability --event-type PostToolUse --summarize"
          }
        ]
      }
    ],
    ... (all 12 event types)
  }
}
```

#### Step 2.3: Update Python import paths

The Python scripts use relative imports like `from utils.summarizer import ...`. Since `uv run` sets the working directory to the script's location, these should continue to work. However, we need to verify and potentially add `sys.path` manipulation for robustness:

```python
# At top of each script that imports from utils/
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
```

### Phase 3: Create Plugin Commands

#### Step 3.1: `/observability:start` command
Creates `commands/start.md` — a slash command that starts the server and client dashboard.

#### Step 3.2: `/observability:stop` command
Creates `commands/stop.md` — stops the server and client processes.

#### Step 3.3: `/observability:status` command
Creates `commands/status.md` — checks if server/client are running and shows URLs.

#### Step 3.4: `/observability:reset-db` command
Creates `commands/reset-db.md` — clears the event database.

### Phase 4: Create Dependency Management

#### Step 4.1: Create `scripts/ensure-deps.sh`
A script that checks for required dependencies (bun, uv) and provides installation guidance. Called by the SessionStart hook or start command.

#### Step 4.2: Update `scripts/start-system.sh`
Update to use `${CLAUDE_PLUGIN_ROOT}` for paths instead of relative `$SCRIPT_DIR/..` references. Add dependency checking.

### Phase 5: Separate Personal Config from Plugin

#### Step 5.1: Clean `.claude/settings.json`
Remove hook configuration (now in `hooks/hooks.json`). Keep only:
- Personal `env` settings
- `teammateMode`
- `statusLine`
- Any non-observability hooks the user wants to keep

#### Step 5.2: Keep personal `.claude/` components in place
Commands, agents, skills, output-styles, and status_lines stay in `.claude/` — they are the user's personal workflow tools, not part of the plugin.

### Phase 6: Update Source App Identifier

#### Step 6.1: Rename source_app
Change the default `--source-app` from `cc-hook-multi-agent-obvs` to `cc-observability` (cleaner plugin identity).

### Phase 7: Documentation

#### Step 7.1: Update README.md
Add plugin installation instructions alongside the existing manual setup:
```markdown
## Quick Install (Plugin)
/plugin marketplace add ehartye/claude-code-hooks-multi-agent-observability
/plugin install observability@observability-dev

## Manual Setup
(existing instructions)
```

#### Step 7.2: Update CLAUDE.md
Add plugin context for Claude Code sessions.

### Phase 8: Testing

#### Step 8.1: Test with `--plugin-dir`
```bash
claude --plugin-dir ./
```
Verify hooks register, commands appear, dashboard starts.

#### Step 8.2: Test event flow
Send test events and verify they appear in the dashboard.

---

## Key Design Decisions

### 1. Source app naming
**Decision**: Change from `cc-hook-multi-agent-obvs` to `cc-observability`.
**Reason**: Cleaner, plugin-appropriate name. The `--source-app` flag can still be overridden by users.

### 2. Server lifecycle management
**Decision**: Use explicit `/observability:start` and `/observability:stop` commands rather than auto-starting on SessionStart.
**Reason**: Auto-starting a server + client on every session is aggressive. Users should opt-in to running the dashboard. The hooks will still fire and silently fail if the server isn't running (send_event.py already exits 0 on failure).

### 3. What stays vs. what goes
**Decision**: Only observability-specific hooks, server, client, and commands become the plugin. Personal commands/agents/skills/output-styles stay in `.claude/`.
**Reason**: The plugin should be single-purpose and distributable. Users shouldn't get worktree-manager or video-processor skills when they install an observability plugin.

### 4. Hook separation (validation vs. observability)
**Decision**: Keep both validation hooks (pre_tool_use.py) and observability hooks (send_event.py) in the plugin.
**Reason**: The pre_tool_use.py validation (blocking rm -rf, .env access) is a useful security feature that complements observability. However, this is debatable — consider making it optional or a separate plugin in the future.

### 5. Python dependency management
**Decision**: Rely on `uv run --script` with inline dependency declarations.
**Reason**: This already works and requires only `uv` to be installed. No pip, no virtualenv, no requirements.txt. The `uv` tool handles caching and resolution transparently.

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| `${CLAUDE_PLUGIN_ROOT}` may not expand in all contexts | Test extensively with `--plugin-dir`; fall back to absolute paths in scripts |
| Python relative imports may break from new directory structure | Add explicit `sys.path` manipulation; test with uv run from various CWDs |
| Plugin installation copies files — server node_modules won't be included | `ensure-deps.sh` runs `bun install` on first start; document in README |
| Users may have conflicting hooks in their `.claude/settings.json` | Document that plugin hooks merge with user hooks; provide guidance on precedence |
| Server/client ports may conflict | Keep configurable via environment variables; document defaults |

---

## Estimated Scope

- **Files to create**: ~8 (plugin.json, marketplace.json, hooks.json, 4 command .md files, ensure-deps.sh)
- **Files to move**: ~20 (hook scripts + utils + validators from `.claude/hooks/` to `hooks/scripts/`)
- **Files to modify**: ~15 (path references in Python scripts, justfile, start/reset scripts, settings.json, README, CLAUDE.md)
- **Files unchanged**: Server and client source code (apps/)
