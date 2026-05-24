# Plugins reference

Complete technical reference for Claude Code plugin system, including schemas, CLI commands, and component specifications.

A **plugin** is a self-contained directory of components that extends Claude Code with custom functionality. Plugin components include skills, agents, hooks, MCP servers, LSP servers, and monitors.

## Plugin components reference

### Skills

Plugins add skills to Claude Code, creating `/name` shortcuts that you or Claude can invoke.

**Location**: `skills/` or `commands/` directory in plugin root, or a single `SKILL.md` file at the plugin root

**File format**: Skills are directories with `SKILL.md`; commands are simple markdown files

**Skill structure**:

```
skills/
├── pdf-processor/
│   ├── SKILL.md
│   ├── reference.md (optional)
│   └── scripts/ (optional)
└── code-reviewer/
    └── SKILL.md
```

Skills and commands are automatically discovered when the plugin is installed. Claude can invoke them automatically based on task context.

### Agents

**Location**: `agents/` directory in plugin root

**File format**: Markdown files describing agent capabilities

```markdown
---
name: agent-name
description: What this agent specializes in and when Claude should invoke it
model: sonnet
effort: medium
maxTurns: 20
disallowedTools: Write, Edit
---

Detailed system prompt for the agent describing its role, expertise, and behavior.
```

Plugin agents support `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, and `isolation` frontmatter fields. The only valid `isolation` value is `"worktree"`. For security reasons, `hooks`, `mcpServers`, and `permissionMode` are not supported for plugin-shipped agents.

### Hooks

**Location**: `hooks/hooks.json` in plugin root, or inline in plugin.json

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/format-code.sh"
          }
        ]
      }
    ]
  }
}
```

Plugin hooks respond to the same lifecycle events as user-defined hooks:

| Event                 | When it fires                                                                                                                |
| :-------------------- | :--------------------------------------------------------------------------------------------------------------------------- |
| `SessionStart`        | When a session begins or resumes                                                                                             |
| `Setup`               | When you start Claude Code with `--init-only`, or with `--init` or `--maintenance` in `-p` mode                             |
| `UserPromptSubmit`    | When you submit a prompt, before Claude processes it                                                                         |
| `UserPromptExpansion` | When a user-typed command expands into a prompt, before it reaches Claude. Can block the expansion                           |
| `PreToolUse`          | Before a tool call executes. Can block it                                                                                    |
| `PermissionRequest`   | When a permission dialog appears                                                                                             |
| `PermissionDenied`    | When a tool call is denied by the auto mode classifier. Return `{retry: true}` to tell the model it may retry               |
| `PostToolUse`         | After a tool call succeeds                                                                                                   |
| `PostToolUseFailure`  | After a tool call fails                                                                                                      |
| `PostToolBatch`       | After a full batch of parallel tool calls resolves, before the next model call                                               |
| `Notification`        | When Claude Code sends a notification                                                                                        |
| `SubagentStart`       | When a subagent is spawned                                                                                                   |
| `SubagentStop`        | When a subagent finishes                                                                                                     |
| `TaskCreated`         | When a task is being created via `TaskCreate`                                                                                |
| `TaskCompleted`       | When a task is being marked as completed                                                                                     |
| `Stop`                | When Claude finishes responding                                                                                               |
| `StopFailure`         | When the turn ends due to an API error                                                                                       |
| `TeammateIdle`        | When an agent team teammate is about to go idle                                                                              |
| `InstructionsLoaded`  | When a CLAUDE.md or `.claude/rules/*.md` file is loaded into context                                                        |
| `ConfigChange`        | When a configuration file changes during a session                                                                           |
| `CwdChanged`          | When the working directory changes                                                                                           |
| `FileChanged`         | When a watched file changes on disk. The `matcher` field specifies which filenames to watch                                  |
| `WorktreeCreate`      | When a worktree is being created via `--worktree` or `isolation: "worktree"`. Replaces default git behavior                  |
| `WorktreeRemove`      | When a worktree is being removed                                                                                             |
| `PreCompact`          | Before context compaction                                                                                                    |
| `PostCompact`         | After context compaction completes                                                                                           |
| `Elicitation`         | When an MCP server requests user input during a tool call                                                                    |
| `ElicitationResult`   | After a user responds to an MCP elicitation, before the response is sent back to the server                                 |
| `SessionEnd`          | When a session terminates                                                                                                    |

**Hook types**: `command`, `http`, `mcp_tool`, `prompt`, `agent`

### MCP servers

**Location**: `.mcp.json` in plugin root, or inline in plugin.json

```json
{
  "mcpServers": {
    "plugin-database": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": {
        "DB_PATH": "${CLAUDE_PLUGIN_ROOT}/data"
      }
    }
  }
}
```

Plugin MCP servers start automatically when the plugin is enabled.

### LSP servers

**Location**: `.lsp.json` in plugin root, or inline in `plugin.json`

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

**Inline in `plugin.json`**:

```json
{
  "name": "my-plugin",
  "lspServers": {
    "go": {
      "command": "gopls",
      "args": ["serve"],
      "extensionToLanguage": {
        ".go": "go"
      }
    }
  }
}
```

**Required fields:**

| Field                 | Description                                  |
| :-------------------- | :------------------------------------------- |
| `command`             | The LSP binary to execute (must be in PATH)  |
| `extensionToLanguage` | Maps file extensions to language identifiers |

**Optional fields:**

| Field                   | Description                                                           |
| :---------------------- | :-------------------------------------------------------------------- |
| `args`                  | Command-line arguments for the LSP server                             |
| `transport`             | Communication transport: `stdio` (default) or `socket`                |
| `env`                   | Environment variables to set when starting the server                 |
| `initializationOptions` | Options passed to the server during initialization                    |
| `settings`              | Settings passed via `workspace/didChangeConfiguration`                |
| `workspaceFolder`       | Workspace folder path for the server                                  |
| `startupTimeout`        | Max time to wait for server startup (milliseconds)                    |
| `shutdownTimeout`       | Max time to wait for graceful shutdown (milliseconds)                 |
| `restartOnCrash`        | Whether to automatically restart the server if it crashes             |
| `maxRestarts`           | Maximum number of restart attempts before giving up                   |

The LSP binary must be installed separately by the user.

### Monitors

Plugins can declare background monitors that Claude Code starts automatically when the plugin is active. Each monitor runs a shell command for the lifetime of the session and delivers every stdout line to Claude as a notification.

**Location**: `monitors/monitors.json` in the plugin root, or inline in `plugin.json`

```json
[
  {
    "name": "deploy-status",
    "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/poll-deploy.sh ${user_config.api_endpoint}",
    "description": "Deployment status changes"
  },
  {
    "name": "error-log",
    "command": "tail -F ./logs/error.log",
    "description": "Application error log",
    "when": "on-skill-invoke:debug"
  }
]
```

**Required fields:** `name`, `command`, `description`

**Optional fields:**

| Field  | Description                                                                                                                                        |
| :----- | :------------------------------------------------------------------------------------------------------------------------------------------------- |
| `when` | `"always"` (default) starts at session start. `"on-skill-invoke:<skill-name>"` starts the first time the named skill is dispatched                |

Requires Claude Code v2.1.105 or later.

### Themes

Plugins can ship color themes in `themes/` as JSON files with a `base` preset and `overrides` map. Themes are an experimental component.

```json
{
  "name": "Dracula",
  "base": "dark",
  "overrides": {
    "claude": "#bd93f9",
    "error": "#ff5555",
    "success": "#50fa7b"
  }
}
```

---

## Plugin installation scopes

| Scope     | Settings file                   | Use case                                                 |
| :-------- | :------------------------------ | :------------------------------------------------------- |
| `user`    | `~/.claude/settings.json`       | Personal plugins available across all projects (default) |
| `project` | `.claude/settings.json`         | Team plugins shared via version control                  |
| `local`   | `.claude/settings.local.json`   | Project-specific plugins, gitignored                     |
| `managed` | Managed settings                | Managed plugins (read-only, update only)                 |

---

## Plugin manifest schema

The `.claude-plugin/plugin.json` file defines your plugin's metadata and configuration.

The manifest is optional. If omitted, Claude Code auto-discovers components in default locations and derives the plugin name from the directory name.

### Complete schema

```json
{
  "name": "plugin-name",
  "displayName": "Plugin Name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "skills": "./custom/skills/",
  "commands": ["./custom/commands/special.md"],
  "agents": ["./custom/agents/reviewer.md"],
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "outputStyles": "./styles/",
  "lspServers": "./.lsp.json",
  "experimental": {
    "themes": "./themes/",
    "monitors": "./monitors.json"
  },
  "dependencies": [
    "helper-lib",
    { "name": "secrets-vault", "version": "~2.1.0" }
  ]
}
```

### Required fields

If you include a manifest, `name` is the only required field.

| Field  | Type   | Description                               |
| :----- | :----- | :---------------------------------------- |
| `name` | string | Unique identifier (kebab-case, no spaces) |

### Metadata fields

| Field         | Type   | Description                                                               |
| :------------ | :----- | :------------------------------------------------------------------------ |
| `$schema`     | string | JSON Schema URL for editor autocomplete and validation                    |
| `displayName` | string | Human-readable name shown in the `/plugin` picker and other UI surfaces   |
| `version`     | string | Semantic version. If omitted, git commit SHA is used                      |
| `description` | string | Brief explanation of plugin purpose                                        |
| `author`      | object | Author information                                                         |
| `homepage`    | string | Documentation URL                                                          |
| `repository`  | string | Source code URL                                                            |
| `license`     | string | License identifier                                                         |
| `keywords`    | array  | Discovery tags                                                             |

### Component path fields

| Field                   | Type                  | Description                                                                                                    |
| :---------------------- | :-------------------- | :------------------------------------------------------------------------------------------------------------- |
| `skills`                | string\|array         | Custom skill directories (in addition to default `skills/`)                                                    |
| `commands`              | string\|array         | Custom flat `.md` skill files or directories (replaces default `commands/`)                                    |
| `agents`                | string\|array         | Custom agent files (replaces default `agents/`)                                                                |
| `hooks`                 | string\|array\|object | Hook config paths or inline config                                                                             |
| `mcpServers`            | string\|array\|object | MCP config paths or inline config                                                                              |
| `outputStyles`          | string\|array         | Custom output style files/directories (replaces default `output-styles/`)                                      |
| `lspServers`            | string\|array\|object | Language Server Protocol configs                                                                               |
| `experimental.themes`   | string\|array         | Color theme files/directories (replaces default `themes/`)                                                     |
| `experimental.monitors` | string\|array         | Background monitor configurations                                                                              |
| `userConfig`            | object                | User-configurable values prompted at enable time                                                               |
| `channels`              | array                 | Channel declarations for message injection                                                                     |
| `dependencies`          | array                 | Other plugins this plugin requires, optionally with semver version constraints                                 |

### Path behavior rules

- **Replaces the default**: `commands`, `agents`, `outputStyles`, `experimental.themes`, `experimental.monitors`
- **Adds to the default**: `skills` — the default `skills/` directory is always scanned alongside any listed paths
- **Own merge rules**: hooks, MCP servers, and LSP servers (see each section)

All paths must be relative to the plugin root and start with `./`.

**Single-skill plugin auto-discovery**: A plugin that has a `SKILL.md` at its root, no `skills/` subdirectory, and no `skills` manifest field is automatically loaded as a single-skill plugin (Claude Code v2.1.142+). The skill's invocation name comes from the frontmatter `name` field, or the directory basename as fallback.

### Environment variables

| Variable               | Description                                                                  |
| :--------------------- | :--------------------------------------------------------------------------- |
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the plugin's installation directory                        |
| `${CLAUDE_PLUGIN_DATA}` | Persistent directory for plugin state that survives updates                 |
| `${CLAUDE_PROJECT_DIR}` | The project root                                                             |

Available for substitution in skill content, agent content, hook commands, monitor commands, and MCP or LSP server configs.

### Unrecognized fields

Claude Code ignores top-level fields it does not recognize. `claude plugin validate` reports them as warnings, not errors. Pass `--strict` to treat warnings as errors.

---

## Plugin directory structure

```
enterprise-plugin/
├── .claude-plugin/           # Metadata directory (optional)
│   └── plugin.json             # plugin manifest
├── skills/                   # Skills
│   ├── code-reviewer/
│   │   └── SKILL.md
│   └── pdf-processor/
│       ├── SKILL.md
│       └── scripts/
├── commands/                 # Skills as flat .md files
├── agents/                   # Subagent definitions
├── output-styles/            # Output style definitions
├── themes/                   # Color theme definitions
├── monitors/                 # Background monitor configurations
│   └── monitors.json
├── hooks/                    # Hook configurations
│   └── hooks.json
├── bin/                      # Plugin executables added to PATH
├── settings.json             # Default settings for the plugin
├── .mcp.json                 # MCP server definitions
├── .lsp.json                 # LSP server configurations
└── scripts/                  # Hook and utility scripts
```

**Important**: The `.claude-plugin/` directory contains only `plugin.json`. All other directories (`commands/`, `agents/`, `skills/`, `hooks/`) must be at the plugin root, not inside `.claude-plugin/`.

### File locations reference

| Component         | Default Location             |
| :---------------- | :--------------------------- |
| **Manifest**      | `.claude-plugin/plugin.json` |
| **Skills**        | `skills/`                    |
| **Commands**      | `commands/`                  |
| **Agents**        | `agents/`                    |
| **Output styles** | `output-styles/`             |
| **Themes**        | `themes/`                    |
| **Hooks**         | `hooks/hooks.json`           |
| **MCP servers**   | `.mcp.json`                  |
| **LSP servers**   | `.lsp.json`                  |
| **Monitors**      | `monitors/monitors.json`     |
| **Executables**   | `bin/`                       |
| **Settings**      | `settings.json`              |

---

## CLI commands reference

### plugin install

```bash
claude plugin install <plugin> [options]
```

Options: `-s, --scope <scope>` (`user` | `project` | `local`, default `user`)

### plugin uninstall

```bash
claude plugin uninstall <plugin> [options]
```

Options: `-s, --scope`, `--keep-data`, `--prune`, `-y, --yes`

Aliases: `remove`, `rm`

### plugin prune

Remove auto-installed plugin dependencies no longer required by any installed plugin.

```bash
claude plugin prune [options]
```

Options: `-s, --scope`, `--dry-run`, `-y, --yes`

Aliases: `autoremove`. Requires Claude Code v2.1.121+.

### plugin enable / disable

```bash
claude plugin enable <plugin> [options]
claude plugin disable <plugin> [options]
```

Options: `-s, --scope`

### plugin update

```bash
claude plugin update <plugin> [options]
```

Options: `-s, --scope` (`user` | `project` | `local` | `managed`)

### plugin list

```bash
claude plugin list [--json] [--available]
```

### plugin details

Show a plugin's component inventory and projected token cost.

```bash
claude plugin details <name>
```

### plugin tag

Create a release git tag for the plugin in the current directory.

```bash
claude plugin tag [--push] [--dry-run] [-f, --force]
```

---

## Version management

The version is resolved from the first of these that is set:

1. The `version` field in `plugin.json`
2. The `version` field in the marketplace entry in `marketplace.json`
3. The git commit SHA (for git-hosted sources)
4. `unknown`

If `version` is set in `plugin.json`, it takes precedence over the marketplace entry. Users only receive updates when the version is bumped — pushing new commits without bumping has no effect.

| Approach               | How                                      | Update behavior                              |
| :--------------------- | :--------------------------------------- | :------------------------------------------- |
| **Explicit version**   | Set `"version": "2.1.0"` in `plugin.json` | Updates only when version field is bumped    |
| **Commit-SHA version** | Omit `version` from both files           | Updates on every new commit to the git source |

---

## Plugin caching

Marketplace plugins are copied to `~/.claude/plugins/cache` rather than used in-place. Plugins cannot reference files outside their directory. Previous version directories are removed automatically 7 days after an update.

---

## Debugging and development tools

- `claude --debug` shows plugin loading details, component registration, and MCP server initialization
- `claude plugin validate ./my-plugin` checks `plugin.json`, skill/agent frontmatter, and `hooks.json` for errors
- `claude plugin validate ./my-plugin --strict` treats unrecognized-field warnings as errors

### Common issues

| Issue                               | Cause                     | Solution                                   |
| :---------------------------------- | :------------------------ | :----------------------------------------- |
| Plugin not loading                  | Invalid `plugin.json`     | Run `claude plugin validate`               |
| Skills not appearing                | Wrong directory structure | Ensure `skills/` is at the plugin root     |
| Hooks not firing                    | Script not executable     | Run `chmod +x script.sh`                   |
| MCP server fails                    | Missing variable          | Use `${CLAUDE_PLUGIN_ROOT}` for all paths  |
| LSP `Executable not found in $PATH` | Binary not installed      | Install the language server binary         |
