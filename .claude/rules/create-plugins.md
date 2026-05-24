# Create plugins

Plugins let you extend Claude Code with custom functionality that can be shared across projects and teams. This guide covers creating plugins with skills, agents, hooks, and MCP servers.

## When to use plugins vs standalone configuration

| Approach                            | Skill names          | Best for                                                                                    |
| :---------------------------------- | :------------------- | :------------------------------------------------------------------------------------------ |
| **Standalone** (`.claude/`)         | `/hello`             | Personal workflows, project-specific customizations, quick experiments                      |
| **Plugins** (directories with `.claude-plugin/plugin.json`) | `/plugin-name:hello` | Sharing with teammates, distributing to community, versioned releases, reusable across projects |

Use **standalone** when customizing Claude Code for a single project or experimenting. Use **plugins** when you want to share across projects or distribute through a marketplace.

Start with standalone configuration in `.claude/` for quick iteration, then convert to a plugin when ready to share.

## Plugin quickstart

### 1. Create the plugin directory

```bash
mkdir my-first-plugin
```

### 2. Create the plugin manifest

```bash
mkdir my-first-plugin/.claude-plugin
```

`my-first-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "my-first-plugin",
  "description": "A greeting plugin to learn the basics",
  "version": "1.0.0",
  "author": {
    "name": "Your Name"
  }
}
```

The `name` field is the unique identifier and skill namespace — skills are prefixed with it (e.g., `/my-first-plugin:hello`).

### 3. Add a skill

```bash
mkdir -p my-first-plugin/skills/hello
```

`my-first-plugin/skills/hello/SKILL.md`:

```markdown
---
description: Greet the user with a friendly message
disable-model-invocation: true
---

Greet the user warmly and ask how you can help them today.
```

### 4. Test your plugin

```bash
claude --plugin-dir ./my-first-plugin
```

Then try `/my-first-plugin:hello`. Use `/reload-plugins` after making changes.

### 5. Add skill arguments

The `$ARGUMENTS` placeholder captures any text the user provides after the skill name:

```markdown
---
description: Greet the user with a personalized message
---

Greet the user named "$ARGUMENTS" warmly and ask how you can help them today.
```

Then try `/my-first-plugin:hello Alex`.

## Plugin structure

**Important**: Don't put `commands/`, `agents/`, `skills/`, or `hooks/` inside the `.claude-plugin/` directory. Only `plugin.json` goes inside `.claude-plugin/`. All other directories must be at the plugin root.

| Directory         | Location    | Purpose                                           |
| :---------------- | :---------- | :------------------------------------------------ |
| `.claude-plugin/` | Plugin root | Contains `plugin.json` manifest                   |
| `skills/`         | Plugin root | Skills as `<name>/SKILL.md` directories            |
| `commands/`       | Plugin root | Skills as flat Markdown files                      |
| `agents/`         | Plugin root | Custom agent definitions                           |
| `hooks/`          | Plugin root | Event handlers in `hooks.json`                     |
| `.mcp.json`       | Plugin root | MCP server configurations                          |
| `.lsp.json`       | Plugin root | LSP server configurations                          |
| `monitors/`       | Plugin root | Background monitor configurations                  |
| `bin/`            | Plugin root | Executables added to the Bash tool's `PATH`        |
| `settings.json`   | Plugin root | Default settings applied when the plugin is enabled |

## Adding skills to a plugin

Skills live in the `skills/` directory. Each skill is a folder containing a `SKILL.md` with YAML frontmatter and instructions. Include a `description` so Claude knows when to use the skill:

```yaml
---
description: Reviews code for best practices and potential issues. Use when reviewing code, checking PRs, or analyzing code quality.
---

When reviewing code, check for:
1. Code organization and structure
2. Error handling
3. Security concerns
4. Test coverage
```

For complete skill authoring guidance, see the Claude Code Skills documentation.

## Adding LSP servers to a plugin

Add an `.lsp.json` file to your plugin:

```json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": {
      ".go": "go"
    }
  }
}
```

Users installing your plugin must have the language server binary installed. LSP config changes require a full restart of Claude Code to take effect.

## Adding background monitors

Add `monitors/monitors.json` at the plugin root:

```json
[
  {
    "name": "error-log",
    "command": "tail -F ./logs/error.log",
    "description": "Application error log"
  }
]
```

Each stdout line is delivered to Claude as a notification during the session.

## Shipping default settings

Include `settings.json` at the plugin root. Currently only the `agent` and `subagentStatusLine` keys are supported:

```json
{
  "agent": "security-reviewer"
}
```

## Testing plugins locally

```bash
# Load a plugin directory
claude --plugin-dir ./my-plugin

# Load a zip archive (requires Claude Code v2.1.128+)
claude --plugin-dir ./my-plugin.zip

# Load multiple plugins
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two

# Load from a URL
claude --plugin-url https://example.com/my-plugin.zip
```

When a `--plugin-dir` plugin has the same name as an installed marketplace plugin, the local copy takes precedence for that session. Run `/reload-plugins` to pick up changes without restarting.

## Converting existing configurations to plugins

To migrate from `.claude/` to a plugin:

1. Create `my-plugin/.claude-plugin/plugin.json`
2. Copy `.claude/commands/` → `my-plugin/commands/`
3. Copy `.claude/agents/` → `my-plugin/agents/`
4. Copy `.claude/skills/` → `my-plugin/skills/`
5. Move hooks from `settings.json` to `my-plugin/hooks/hooks.json` (same format, wrapped in `{"hooks": {...}}`)

| Standalone (`.claude/`)       | Plugin                           |
| :---------------------------- | :------------------------------- |
| Only available in one project | Can be shared via marketplaces   |
| Files in `.claude/commands/`  | Files in `plugin-name/commands/` |
| Hooks in `settings.json`      | Hooks in `hooks/hooks.json`      |

## Distributing plugins

To distribute through a marketplace:

1. Add a `README.md` with installation and usage instructions
2. Decide on a versioning strategy (explicit version vs commit SHA)
3. Create or use a plugin marketplace

### Submitting to the community marketplace

- **Claude.ai**: claude.ai/settings/plugins/submit
- **Console**: platform.claude.com/plugins/submit

Run `claude plugin validate` before submitting. Approved plugins are pinned to a commit SHA in the `anthropics/claude-plugins-community` catalog.

The official marketplace (`claude-plugins-official`) is curated by Anthropic separately — there is no application process.
