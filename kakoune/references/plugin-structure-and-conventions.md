# Plugin structure, modules, naming, and distribution

The conventions that make a script idiomatic and shareable. Sources:
`doc/writing_scripts.asciidoc`, `doc/coding-style.asciidoc`, and the structure of
`rc/` — all paths within the Kakoune source repository, not the installed docs
(those live at `<prefix>/share/kak/doc/`; see SKILL.md for the prefix). This is
the reference behind the upstream-quality checklist in `SKILL.md`.

## How scripts get loaded

- **Autoload.** On startup Kakoune sources every `.kak` file found under its autoload
  paths: `%val{runtime}/autoload/` (the shipped `rc/`, symlinked in) and
  `%val{config}/autoload/` (`~/.config/kak/autoload/`). If an `autoload/` dir exists
  in your config, **only** it is autoloaded — so either symlink the system autoload in
  too, or load things explicitly from `kakrc`.
- **kakrc.** `~/.config/kak/kakrc` is sourced after autoload. Put user config and
  explicit `source`/`require-module` here.
- **`source <file> [args…]`** evaluates another script now; args are `%arg{0}`,
  `%arg{1}`, …. Use `%val{source}` (the *path of the running file*) to locate sibling
  files; take its directory first, e.g.
  `evaluate-commands %sh{ echo "source '$(dirname "$kak_source")/sibling.kak'" }`
  (handy when a plugin spans multiple files).

## Modules: lazy, single-evaluation units

```
provide-module [-override] <name> <commands>
require-module <name>
```

- `provide-module` *declares* a module; its body is **not** run until the first
  `require-module <name>`, then it runs once (like `source`) and is cached.
- `require-module` guarantees the body has run before continuing — use it to express
  dependencies (`require-module fifo`) and to defer expensive setup.
- `-override` lets you redefine a module, but **only if it hasn't been required yet**;
  once evaluated it can't be replaced without restarting. (Plan reloads accordingly —
  see `debugging-and-dev-loop.md`.)
- `ModuleLoaded <name>` hook fires after a module first evaluates.

Loading idioms by plugin type:

- Filetype: `require-module <lang>` inside `WinSetOption filetype=<lang>` (load when
  first used).
- Tool: `hook -once global KakBegin .* %{ require-module <tool> }` (load once at
  startup, after user config).
- Shared dependency: `provide-module a %{ require-module b }` to alias/forward.

## Naming conventions

From `doc/writing_scripts.asciidoc` — follow exactly for shareable code:

- **Prefix everything** with the script/feature name: `tmux-new-window`,
  `comment_line`, `ctags_min_chars`. This namespaces options/commands/faces/hooks.
- **Options use `_`** between words (so the `$kak_opt_<name>` shell variable is a valid
  identifier): `comment_block_begin`, `make_error_pattern`.
- **Commands use `-`** between words (distinguishes them from option names):
  `comment-block`, `make-next-error`.
- **Faces** are `CamelCase` and semantic (`DiagnosticError`); reuse built-ins
  (`keyword`, `string`, …) in highlighters so colorschemes apply.
- **Hook groups** are `<prefix>-<concern>` (`make-hooks`, `rust-indent`) so a regex
  removes them all.

## Documentation

- Every **non-hidden** command and option carries a `-docstring`; it shows in
  completion and `:doc`. First line is the usage summary
  (`name <args>: what it does`).
- Mark internal helpers `-hidden` (commands) / `-hidden` (options) so they don't
  clutter completion.
- Long-form docs: ship a `<name>.asciidoc` next to the script (as `make`, `lint`,
  `doc`, `autorestore` do) and surface it via `:doc`.
- Keep behavior **discoverable**: docstrings on `map`/`enter-user-mode`, autoinfo
  boxes — Kakoune's self-documenting ethos.

## Dependencies and portability

- Minimize dependencies; they must be "reasonable and expected" for the script's
  purpose (a clang plugin may need `clang`; a generic one may not need anything but
  POSIX sh).
- All `%sh{}` is POSIX — see `shell-and-portability.md`. No bashisms, no GNU-only
  flags unless documented.
- Don't reimplement what Unix tools do; shell out (the composability design goal).
- No binary/native plugins and no embedded scripting language by design — the
  extension surface is kakscript + `%sh{}` + the session socket.

## File and repo layout

- One concern per file; group under `filetype/`, `tools/`, etc., mirroring `rc/` if
  you ship several.
- A typical third-party plugin is a repo with one or more `.kak` files plus a
  `README`; users load it by adding it to an autoload path or `source`-ing it.
- **Plugin managers:** `plug.kak` is the common one. It clones plugins and sources
  their `.kak` files; config for a plugin is wrapped in a `plug "user/repo" %{ … }`
  block. You don't need a manager — `source` from `kakrc` or symlinking into
  `autoload/` works — but structure your plugin so a manager can source it
  unconditionally (guard heavy work behind `provide-module`/`require-module`).

## Development / debug loop

The full loop lives in `debugging-and-dev-loop.md`: clean sessions (`kak -n`),
reloading (`:source`, `provide-module -override`), state inspection (`:debug …` and
the `*debug*` buffer), and `:doc` as the live reference (interactive; the same pages
are on disk at `<prefix>/share/kak/doc/` — see that file).

## Contributing upstream (if targeting the Kakoune repo)

`CONTRIBUTING` requires a one-time copyright-waiver commit dedicating your changes to
the public domain (Kakoune is UNLICENSE/public-domain):

```
git commit --allow-empty   # message: "<Name> Copyright Waiver" + the dedication text
```

C++ engine changes follow `doc/coding-style.asciidoc` (C++20, 4-space indent,
`and`/`or`/`not`, `m_` fields, ≤80 cols) — but most contributions to scripting are
`.kak` files governed by the conventions above.
