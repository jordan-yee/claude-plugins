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

### kakoune

A skill for authoring, debugging, and answering questions about [Kakoune](https://kakoune.org) configuration and kakscript plugins.

### repo-reference

A skill that answers questions about a library, tool, or any other open source project by consulting a local Git clone of its source and docs — greppable raw files at the exact version you care about, instead of web pages or recollection.

**Where clones go** is configured per machine in `config.md` under the plugin's data directory (`~/.claude/plugins/data/repo-reference-jordan-yee-claude-plugins/`). The layout is a base directory holding one directory per host, each holding `<org>/<repo>` — by default the base is your home dir, so GitHub repos land in `~/github/<org>/<repo>` and a Codeberg repo would go to a parallel `~/codeberg/<org>/<repo>`. Three layers resolve a repo, most specific winning:

| Layer      | Config entry                                     | Resolves to                    |
| :--------- | :----------------------------------------------- | :----------------------------- |
| Per-repo   | `https://github.com/torvalds/linux: ~/big/linux` | that exact path                |
| Per-domain | `github.com: ~/github`                           | `~/github/<org>/<repo>`        |
| Default    | base `~`, naming `short`                         | `~/<host-dir>/<org>/<repo>`    |

On first use the skill looks for directories that already hold clones and follows the convention it finds — including the case where the host directories are nested under a container such as `~/src/github` and `~/src/codeberg`, which it reads as base `~/src`. It proposes what it found and writes `config.md` once you confirm. Edit that file any time to move things around.

Alongside it, `index.md` accumulates short notes on each repo — where its docs live, which directory holds the interesting source. Both files live outside the plugin cache, so they survive plugin updates.

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
