# codex-review

Claude Code skill that requests **independent code reviews from Codex CLI** (GPT-based) via MCP bridge.

Write code with Claude, review it with Codex — cross-model validation by design.

## How It Works

```
Claude Code ──git diff──▶ MCP Bridge ──▶ Codex CLI ──▶ Review Result
                              ▲
                        codex mcp-server
```

1. Collects `git diff` (staged + unstaged) from your project
2. Sends changes to Codex via MCP bridge with a structured review prompt
3. Codex reviews for correctness, security, performance, maintainability
4. Results are summarized back in your Claude Code session

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/nerdmakr/codex-review/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/nerdmakr/codex-review.git
cd codex-review
bash install.sh
```

### Prerequisites

- [Node.js](https://nodejs.org) (v18+)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)

The installer will handle the rest (Codex CLI, OAuth login, MCP registration, permissions, skill file).

## Usage

Inside Claude Code:

| Command | Description |
|---------|-------------|
| `/codex-review` | Basic review of current changes |
| `/codex-review deep` | Deep review (architecture, security, performance, concurrency) |
| `/codex-review ask <question>` | Follow-up question on the previous review |

### Example

```
> /codex-review

## Codex Code Review Result
### Summary
2 warnings, 1 suggestion found in 3 changed files.
### Issues
🟡 Warning: Unvalidated user input at src/api/handler.ts:42
🟡 Warning: Missing error handling in async function at lib/db.ts:18
🔵 Suggestion: Consider extracting duplicate logic at utils/format.ts:7,15
### Top Priorities
1. Add input validation for handler endpoint
2. Wrap async call in try-catch
3. Extract shared formatting logic
🧵 threadId: abc123

> /codex-review ask Can you suggest the exact validation code for the handler?
```

## What the Installer Does

| Step | Action |
|------|--------|
| 1 | Checks Node.js, npm, Claude CLI |
| 2 | Installs Codex CLI (`npm install -g @openai/codex`) |
| 3 | Runs Codex OAuth login (`codex --full-setup`) |
| 4 | Registers MCP server (`claude mcp add codex-bridge`) |
| 5 | Adds tool permissions to `~/.claude/settings.json` |
| 6 | Creates skill file at `~/.claude/skills/codex-review/SKILL.md` |

All steps are idempotent — already-installed components are skipped.

## Uninstall

```bash
# Remove skill
rm -rf ~/.claude/skills/codex-review

# Remove MCP server
claude mcp remove codex-bridge

# (Optional) Remove Codex CLI
npm uninstall -g @openai/codex
```

Then remove `mcp__codex-bridge__codex` and `mcp__codex-bridge__codex-reply` from `~/.claude/settings.json` permissions.

## License

MIT
