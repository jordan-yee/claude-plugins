# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Reference docs

Official Claude Code plugin documentation is saved as rule files for reference:

- `.claude/rules/plugins-reference.md` — complete technical reference: manifest schema, all
  component types, CLI commands, versioning, and debugging
- `.claude/rules/create-plugins.md` — authoring guide: plugin structure, skill authoring,
  LSP/monitor/hook setup, local testing, and distribution

## What this repo is

A personal Claude Code plugin marketplace hosted at `jordan-yee/claude-plugins`. Users add it
with `/plugin marketplace add jordan-yee/claude-plugins` and install individual plugins from it.

There are no build, lint, or test commands — this is a content repository.

## Marketplace structure

`.claude-plugin/marketplace.json` at the repo root is the marketplace index. Every plugin needs
an entry here with `name`, `description`, `version`, `source` (relative path to the plugin
directory), and `category`.

Each plugin lives in its own top-level directory.

## Plugin manifest conventions

`marketplace.json` is the single source of truth for `name`, `description`, `version`, and
`category`. Plugin-level `.claude-plugin/plugin.json` files exist only for fields that have no
equivalent in the marketplace entry: `homepage`, `repository`, `keywords`, and functional fields
like `lspServers`. Do not duplicate fields between the two files.

The manifest `name` field is intentionally omitted from `plugin.json` to avoid duplication;
Claude Code falls back to the directory name.

## Plugin types

**LSP plugin** (e.g. `clojure-lsp`): requires a `.lsp.json` mapping language server config, and
a `.claude-plugin/plugin.json` with `"lspServers": "./.lsp.json"` pointing to it. LSP config
changes require a full restart of Claude Code to take effect.

**Skill plugin** (e.g. `kakoune`): a `SKILL.md` at the plugin root is auto-discovered as a
single-skill plugin. No `skills/` subdirectory or manifest `skills` field is needed. The skill's
invocation name comes from the `name` field in `SKILL.md` frontmatter, falling back to the
directory name.

## Adding a new plugin

1. Create a top-level directory for the plugin.
2. Add an entry to `.claude-plugin/marketplace.json`.
3. Add plugin type-specific files (`.lsp.json` for LSP plugins, `SKILL.md` for skill plugins).
4. Optionally add `.claude-plugin/plugin.json` with `homepage`, `repository`, `keywords`, and
   any functional fields — but only if those fields aren't already covered by `marketplace.json`.

## Versioning

`version` in `marketplace.json` controls when users receive updates: it must be bumped for
changes to reach users. If omitted, the git commit SHA is used and every push counts as a new
version. Current plugins omit `version` so the git commit SHA is used — every push is a new version.
