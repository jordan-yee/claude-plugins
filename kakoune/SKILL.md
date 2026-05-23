---
name: kakoune
description: >-
  Author and debug Kakoune editor configuration and plugins written in kakscript
  — .kak files, kakrc, filetype/highlighter/indentation definitions, hooks,
  options, faces, key mappings, user modes, and shell-integration commands. Use
  this whenever editing a .kak file or kakrc, writing or modifying a Kakoune
  plugin, building a filetype or highlighter or indent-on-newline script,
  debugging kakscript quoting/expansion/hook problems, or answering "how do I … in
  Kakoune config". Covers command parsing and %-string quoting, the
  %val/%opt/%reg/%arg/%sh expansion system, evaluate-commands / execute-keys and
  draft contexts, the provide-module / require-module plugin pattern, highlighter
  regions, hook-group cleanup discipline, and POSIX-shell integration.
---

# Writing Kakoune scripts and plugins

Kakoune is configured and extended in **kakscript**: the same command language you
type at the `:` prompt, saved into `.kak` files. There is no embedded Lua/Vimscript
— the language is "commands + expansions," and anything beyond that is delegated to
a POSIX shell via `%sh{ … }`.

This file is the map: read the focused reference under `references/` for whatever
you touch — quoting and hook semantics are precise and unforgiving, don't guess.

## Mental model

- **Commands** are whitespace-separated words terminated by newline or `;`. The
  first word is the command, the rest are arguments.
- **Expansions** (`%val{}`, `%opt{}`, `%reg{}`, `%arg{}`, `%sh{}`, `%file{}`,
  `%exp{}`) are substituted *before* the command runs — but only when unquoted or
  inside `"…"`, never inside `'…'` or `%{…}`.
- **Normal mode is the editing language.** There is no `delete-line`; you script
  edits by feeding normal-mode keys to `execute-keys` (`x` select line, `d` delete,
  `<a-k>regex<ret>` keep selections matching). `<a-k>` doubles as kakscript's `if`:
  it errors when nothing matches and `try` swallows that error. See
  `references/regex.md` and `references/execution-model.md`.
- **Client–server, shell-first.** Sorting, formatting, completion, linting are done
  by external Unix tools, not reimplemented. The integration surface is `%sh{}`,
  the `$kak_*` env vars, the command/response fifos, and `kak -p <session>` for
  async writes back into the editor. See `references/shell-and-portability.md`.

## Scopes (cross-cutting — used by options, hooks, highlighters, faces, maps, aliases)

Values resolve narrowest-first along this chain:

```
local  >  window  >  buffer  >  global
```

- `global` — the whole session. `buffer` — one buffer. `window` — one view onto a
  buffer (a buffer shown in two windows can differ, e.g. `filetype`). `local` — a
  temporary scope injected for the duration of each `evaluate-commands` and each
  `define-command` body.
- `set-option`/`unset-option` also accept `current` (the narrowest scope where the
  option is already set) and `buffer=<buffile>` to target a specific buffer.
- The `shared` scope is special to highlighters: filetype highlighters live in
  `shared/<lang>` and are attached to a window with `ref`.

## The five things that cause 90% of kakscript bugs

1. **`%{ … }` is verbatim now, re-parsed later.** A command/hook/map body stored in
   `%{ … }` is *not* expanded when defined. `%val{client}` inside it expands only
   when the body later runs as commands. This is why `%sh{}` blocks cannot use
   `%val{…}` and must read `$kak_*` environment variables instead. See
   `references/command-parsing-and-quoting.md` and `references/expansions.md`.
2. **Pick a delimiter that doesn't collide with the body.** `%{…}` is the default,
   but when the body contains unbalanced braces or regex, switch delimiters
   (`%[ ]`, `%( )`, `%< >`, or non-nestable `%| |`, `%§ §`, `%~ ~`, `%@ @`).
   Upstream nests a different delimiter at each level. See the quoting reference.
3. **Editing from a script must use a draft context.** `execute-keys -draft` (and
   usually `-itersel`) run keys against a *copy* of the user's selections so you
   don't clobber their cursor. Indentation/comment hooks are built entirely from
   this. See `references/execution-model.md`.
4. **Every hook you add in a filetype must be removable.** Tag hooks with
   `-group <ft>-…` and tear them down with a `hook -once -always window
   WinSetOption filetype=.* %{ remove-hooks window <ft>-.+ }`. Forgetting this
   leaks behavior across filetypes. See `references/hooks.md`.
5. **Prefix everything and document it.** Every non-hidden option/command/face is
   named after its script and carries a `-docstring`. See
   `references/plugin-structure-and-conventions.md`.

## Which reference to open

| Working on…                                                                                          | Read                                             |
|------------------------------------------------------------------------------------------------------|--------------------------------------------------|
| Quoting, `%`-strings, delimiters, escaping, typed expansions                                         | `references/command-parsing-and-quoting.md`      |
| `%val`/`%opt`/`%reg`/`%arg`/`%sh`/`%file`/`%exp`, `$kak_*` vars, fifos                               | `references/expansions.md`                       |
| `define-command`, `-params`, completion, aliases, `try`/`fail`/`nop`/`echo`/`info`/`prompt`/`on-key` | `references/defining-commands.md`                |
| `evaluate-commands` vs `execute-keys`, `-draft`/`-itersel`/`-save-regs`/`-no-hooks`, scripting edits | `references/execution-model.md`                  |
| `hook`, scopes, groups, `-once`/`-always`, the hook catalog, cleanup                                 | `references/hooks.md`                            |
| `declare-option`/`set-option`, option types incl. `line-specs`/`range-specs`/`completions`           | `references/options.md`                          |
| `add-highlighter`, regions, `ref`/`shared`, regex captures, specs highlighters, faces, markup        | `references/highlighters-and-faces.md`           |
| Key notation, `map`/`unmap`, modes, `declare-user-mode`/`enter-user-mode`, count/register forwarding | `references/keys-and-mappings.md`                |
| Regex dialect, divergences from ECMAScript, `\K`/`\N`/`\Q\E`/`\h`                                    | `references/regex.md`                            |
| POSIX shell rules, `printf` vs `echo`, `kakquote`, `join`, async detached jobs, `kak -p`             | `references/shell-and-portability.md`            |
| **A new filetype / syntax-highlighting / indent script**                                             | `references/filetype-plugin-pattern.md`          |
| **A command that drives an external tool** (build, grep, format, lint, completion, REPL)             | `references/tool-plugin-pattern.md`              |
| File layout, module loading, naming, docstrings, distribution, autoload                              | `references/plugin-structure-and-conventions.md` |
| Debugging, the dev loop, `:doc`, `*debug*`, `:source`/`-override`, `kak -n`                          | `references/debugging-and-dev-loop.md`           |

Complete, copyable starting points live in `assets/`: `example-filetype.kak` (a full
filetype — detection, highlighting, `static_words` completion, indentation) and
`example-tool.kak` (an external-tool command that streams output to a buffer with
jump-to-source). Copy one and adapt it rather than starting from a blank file.

## Verifying kakscript (there is no test framework)

Confirm behaviour by running it and watching Kakoune's own introspection: `:doc
<topic>` (authoritative, matches the installed version), the `*debug*` buffer,
`:debug options|faces|mappings`, and `kak -n` for a clean session. `:doc` is
interactive (it opens a buffer in a running Kakoune); the same pages are installed
on disk as plain asciidoc, readable directly, at
`<prefix>/share/kak/doc/<topic>.asciidoc`, where `<prefix>` matches the `kak` binary
(`/usr/local/bin/kak` → `/usr/local/share/kak/doc/`). Full loop in
`references/debugging-and-dev-loop.md`.

## Kakoune source repository

The skill's references and the installed docs at `<prefix>/share/kak/doc/`
cover most questions. The source tree adds material not in the installation:
contributor guides in `doc/` (`writing_scripts.asciidoc`,
`coding-style.asciidoc`), source-only pages like `doc/pages/autoedit.asciidoc`,
and the `rc/` scripts that form the default autoload. When a question would
benefit from a direct, authoritative look at any of these, ask the user if
they have a local clone of the Kakoune repository and read from it directly
if so.

## Upstream-quality bar (this skill targets shareable code)

The per-pattern references carry the full checklists; the essentials:

- Prefix every option/command/face with the script name (`_` in option words, `-`
  in command words); `-docstring` everything non-hidden, `-hidden` helpers.
- `%sh{}` is POSIX — `[ ]` not `[[ ]]`, `printf` not `echo`, no bashisms or
  GNU-only flags unless that documented dependency is the point of the script.
- Hooks/highlighters/maps are `-group`ed and torn down on filetype/window change;
  highlighters live in `shared/` and attach via `ref`.
- Load lazily (`provide-module` + a `KakBegin`/`WinSetOption` `require-module`),
  not at source time.
