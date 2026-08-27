---
name: repo-reference
description: >-
  Consult a library's docs or source code by cloning its Git repo locally.
  Use whenever you need accurate details about a library, tool, framework, or
  application — API usage, configuration, internals, changelogs, version
  differences — instead of fetching web pages or answering from memory.
  Applies to anything with a Git repo (GitHub, SourceHut, Codeberg, GitLab,
  etc.), even if the user doesn't say "clone" or "repo".
---

# Repo Reference

Raw files in a local clone beat web pages: no HTML to parse, greppable, and
available at the exact version the project uses.

## State lives outside the plugin

This plugin keeps two files in `${CLAUDE_PLUGIN_DATA}` — a per-machine
directory that survives plugin updates. Never write state into the plugin's
own directory; it is a cache that gets replaced on every update.

| File        | Owner | Purpose                                       |
| :---------- | :---- | :-------------------------------------------- |
| `config.md` | User  | Where clones go on this machine               |
| `index.md`  | You   | Per-repo notes worth reusing (see The index)  |

Keep them separate so rewriting notes can never clobber the user's config.

If `${CLAUDE_PLUGIN_DATA}` reaches you unexpanded (you see the literal `${...}`
rather than a path), fall back to `~/.claude/plugins/data/repo-reference-*/`,
creating it if needed, and mention the fallback to the user once.

## Where clones go

Every layout this supports is the same shape — a **base** directory holding one
directory per host, each holding `<org>/<repo>`:

```
~/                         <- base is the home dir (the default)
├── github/mawww/kakoune
└── codeberg/foo/bar

~/src/                     <- base is ~/src; same shape, one level down
├── github/mawww/kakoune
└── codeberg/foo/bar
```

Read `config.md` from the data dir to resolve a repo. Three layers, most
specific winning:

| Layer      | Config entry                                     | Resolves to                     |
| :--------- | :----------------------------------------------- | :------------------------------ |
| Per-repo   | `https://github.com/torvalds/linux: ~/big/linux` | that exact path, used verbatim  |
| Per-domain | `github.com: ~/github`                           | `~/github/<org>/<repo>`         |
| Default    | base `~`, naming `short`                         | `~/<host-dir>/<org>/<repo>`     |

The default layer only decides where a *new* host lands; once you clone from
one, record it as a per-domain entry so the choice is explicit and stable.
`~` expands to the user's home.

**Host directory names** under `short` naming drop the TLD and any `git.`/`www.`
prefix: `github.com` → `github`, `codeberg.org` → `codeberg`, `gitlab.com` →
`gitlab`, `bitbucket.org` → `bitbucket`. When that produces something nobody
would recognize, use the service's common name instead — `git.sr.ht` →
`sourcehut`, not `sr`. Under `full` naming the directory is the bare hostname
(`github.com`), which is what to use when the machine already does that.

**Path-unsafe segments.** Owner and repo names come from the URL as-is, but a
name that isn't safe as a directory component gets normalized first — always
the same way, so a given repo resolves to the same path every time:

- Strip leading characters a shell or CLI reads as syntax rather than text:
  `~` (expands to a home directory) and `-` (parsed as an option flag).
- Replace whitespace and any character that would otherwise need quoting with
  `-`.
- Don't prettify names that are merely ugly — normalize only what would break.
- A multi-level owner (GitLab subgroups) is already valid path structure, so
  let it nest as directories rather than flattening it.

Known case: SourceHut writes owners as `~user`, so `git.sr.ht/~user/aerc` lands
at `<host-dir>/user/aerc`.

### The config file

```markdown
# repo-reference config

Clone locations, most specific wins: per-repo > per-domain > default.

## Default
- Base: ~
- Host directory naming: short

## Per-domain
- github.com: ~/github
- codeberg.org: ~/codeberg

## Per-repo
- https://github.com/torvalds/linux: ~/big/linux
```

### First run on a new machine

If `config.md` doesn't exist, follow whatever convention the machine already
uses rather than imposing one — where clones land is a durable choice the user
lives with.

1. **Look for directories that already hold clones.** Check `~` itself and the
   usual containers (`~/src`, `~/code`, `~/repos`, `~/projects`, `~/git`,
   `~/dev`, `~/ghq`). What you're looking for is a directory whose name reads
   like a host — `github`, `github.com`, `gitlab`, `codeberg` — containing
   `<org>/<repo>` subdirs that are Git repos.
2. **Read the base off where those host dirs sit.** Directly in the home dir
   → base `~`. Sharing a parent like `~/src/github` and `~/src/codeberg` → base
   `~/src`. This is the case worth catching: same convention, one level down.
3. **Read the naming style off their names** — `github` means `short`,
   `github.com` means `full`.
4. **Record every host dir you found** as an explicit per-domain entry, so
   existing clones keep resolving even if the naming derivation would have
   guessed differently.
5. **Propose the result and confirm before writing** — e.g. "`~/github` already
   holds `<org>/<repo>` clones, so: base `~`, meaning a Codeberg repo would go
   to `~/codeberg/<org>/<repo>`. Good?"
6. If nothing turns up, propose the default: base `~`, `short` naming — GitHub
   repos to `~/github/<org>/<repo>`, a parallel `~/codeberg` if Codeberg ever
   comes up.

Write `config.md` once agreed, and don't ask again on later runs.

When the user later wants repos somewhere else, edit `config.md` — and tell them
the path so they can edit it themselves.

## Workflow

1. **Resolve the path** for the repo from `config.md`, then check whether it
   exists. The filesystem is the source of truth for what's cloned — never
   assume from notes.
2. **Search wider before concluding it's absent.** A clone may predate the
   current config or sit under a different org spelling. Glob the known roots
   for the repo name (e.g. `ls -d ~/github/*/<repo> ~/src/*/*/<repo>`) before
   cloning a second copy.
3. **Find the repo URL** if you don't have it. The project's own dependency
   metadata (`deps.edn`, `package.json`, `Cargo.toml`, lockfiles) often names
   it outright — check there first. Otherwise `gh search repos` when `gh` is
   available (fast, terse), else web search.
4. **Confirm with the user** before cloning: "I found the repo at \<url\> — is
   that correct?" Skip this when the URL came from the project's own dependency
   metadata or lockfile; that's authoritative.
5. **Clone** to the resolved path, creating parent dirs as needed:
   `git clone --filter=blob:none <url> <path>`
   The blobless filter fetches file contents on demand, so large repos clone in
   a fraction of the time while keeping full history and every tag — exactly
   what you need for reference lookups. Use a plain `git clone` instead when
   the user plans to work in the repo or wants it usable offline.
6. **Answer at the right version** — see below.
7. **Record what you learned** in `index.md` if it's worth reusing.

## Reading a specific version

Find the version the project depends on in its dependency files, then read at
that ref. `git -C <path> fetch --tags` first if the tag isn't present yet.

Prefer commands that read a ref directly over checking one out — they never
touch the working tree, so a clone the user has open, mid-edit, or on a feature
branch is completely undisturbed:

| Need                       | Command                                            |
| :------------------------- | :------------------------------------------------- |
| Find a symbol at a version | `git -C <path> grep -n '<pattern>' <ref> -- <glob>` |
| Read one file at a version | `git -C <path> show <ref>:<file>`                   |
| List files at a version    | `git -C <path> ls-tree -r --name-only <ref>`        |
| What changed between two   | `git -C <path> log --oneline <old>..<new> -- <dir>` |
| Diff an API across versions| `git -C <path> diff <old> <new> -- <file>`          |

This is also what makes "how did this behave in 1.2 vs 2.0?" cheap: read both
refs in the same clone, no switching.

Check out a branch or tag only when you genuinely need a working tree — to
build or run something. Say so before you do, since it mutates a directory the
user may be relying on.

If no particular version matters, read the default branch, pulling first if the
clone is stale.

## Finding info efficiently

- Look for `doc/`, `docs/`, or top-level `*.md`/`*.adoc` files first — README,
  CHANGELOG, and design docs answer most questions without touching source.
- Grep for the public API symbol you care about rather than reading files
  top-to-bottom. Read source when docs are thin or you need exact behavior.
- Tests are documentation: a repo's test suite shows real call signatures and
  edge-case behavior that prose docs often gloss over.

## The index

`index.md` in the data dir holds what the filesystem can't tell you: the repo's
URL and short pointers to where its useful content lives. It is a notes cache,
not a record of what's cloned — so it can't go stale about whether a clone
exists, and you never need to prune it when a clone is deleted.

Heading is `<org>/<repo>`, since repo names collide across orgs:

```markdown
## mawww/kakoune
- URL: https://github.com/mawww/kakoune
- Notes: docs in doc/pages/*.asciidoc; built-in kak scripts in rc/
```

Read the entry for the repo you're working with; you don't need the whole file.
Add or update an entry whenever you clone a repo or discover where its docs
live. Keep notes to location pointers — a future lookup should land in the
right file immediately. Don't summarize the library's content there; that goes
stale and the repo already says it better.
