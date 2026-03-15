# claude-plugins

My personal Claude Code plugin marketplace — a collection of custom plugins for use across projects and machines.

## Plugins

### clojure-lsp

Connects Claude Code to the [clojure-lsp](https://clojure-lsp.io/) language server, providing real-time code intelligence for Clojure projects.

**Features:**
- Go to definition
- Find references
- Hover documentation
- Diagnostics (errors and warnings)

**Supported file types:** `.clj`, `.cljs`, `.cljc`, `.edn`

**Prerequisite:** The `clojure-lsp` binary must be installed and available on your `$PATH`. See [clojure-lsp installation](https://clojure-lsp.io/installation/).

## Usage

### 1. Add the marketplace

```shell
/plugin marketplace add jordan-yee/claude-plugins
```

### 2. Install a plugin

```shell
/plugin install clojure-lsp@jordan-yee-claude-plugins
```

### 3. Update plugins

To pull the latest changes from this marketplace:

```shell
/plugin marketplace update
```

> **Note:** Auto-updates are disabled by default for third-party marketplaces. To enable automatic updates at startup, go to `/plugin` → **Marketplaces**, select this marketplace, and choose **Enable auto-update**.

### 4. Uninstall a plugin

```shell
/plugin uninstall clojure-lsp@jordan-yee-claude-plugins
```

## Notes

### LSP plugins require a restart

Unlike other plugin changes, LSP configuration takes effect only after a full restart of Claude Code.

### Verifying clojure-lsp

In a Clojure project, ask Claude:

> Use clojure-lsp to list all symbols in the `[a.namespace.in.your.project]` namespace.

You should see Claude Code use the LSP server with a message like:
```
● LSP(operation: "documentSymbol", file: "[filepath/to/namespace]")
```

## References

- [Claude Code Docs: Discover and install plugins](https://code.claude.com/docs/en/discover-plugins)
- [Claude Code Docs: Create plugins](https://code.claude.com/docs/en/plugins)
- [Claude Code Docs: Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
