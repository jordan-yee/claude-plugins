# Options

Options are Kakoune's named, typed, scoped values — used both to configure the
editor and as a plugin's own storage. Reference: `:doc options`, `:doc scopes`
(interactive; read the same content on disk at
`<prefix>/share/kak/doc/{options,scopes}.asciidoc` — see SKILL.md for the prefix).

## Commands

```
declare-option [-hidden] [-docstring <s>] <type> <name> [<value>...]
set-option [-add|-remove] <scope> <name> <value>...
unset-option <scope> <name>          # fall back to the parent scope's value
update-option <scope> <name>         # refresh types that track the buffer
```

- `declare-option` creates a *new* option (plugin storage). `-hidden` keeps it out of
  completion (use for internal state like `*_flags`, `*_completions`). Add a
  `-docstring` for any option the user is meant to set.
- `set-option` scopes: `global`, `buffer`, `window`, plus `current` (narrowest scope
  already set) and `buffer=<buffile>` (a specific buffer).
- `-add`/`-remove` mutate in place; meaning depends on type (math for `int`, append
  for lists, set-union for `flags`, etc.).
- Read a value with the `%opt{name}` expansion or `$kak_opt_name` in `%sh{}`.

## Types

User-declarable: `int`, `bool`, `str`, `regex` (str validated as a regex),
`int-list`, `str-list`, `str-to-str-map`, `completions`, `line-specs`,
`range-specs`. Built-in-only: `coord`, `enum(...)`, `flags(...)`,
`<type>-to-<type>-map` beyond str→str.

The three that matter most for plugins:

### `str-list` — keyword lists, paths, completion words

Used pervasively for `static_words` (completion) and config lists. Build from the
shell with a `join` helper (see `shell-and-portability.md`):

```
declare-option str-list mylang_static_words   # then, in shell:
printf %s\\n "declare-option str-list mylang_static_words $(join "$keywords" ' ')"
```

### `line-specs` — gutter flags / per-line markers

A timestamp followed by `<line>|<flag text>` entries. Drives the `flag-lines`
highlighter (lint marks, git diff/blame gutters). Escape literal `|`/`\` in the
text as `\|`/`\\`. Always set the timestamp to `%val{timestamp}` and call
`update-option` after edits so positions track changes:

```
declare-option -hidden line-specs my_flags
set-option window my_flags %val{timestamp} '1|{red}!' '3|{yellow}?'
add-highlighter window/ flag-lines Default my_flags
```

### `range-specs` — highlight or replace text ranges

A timestamp followed by `a.b,c.d|string` (or `a.b+len|string`) entries; the string
is a face (for the `ranges` highlighter) or markup (for `replace-ranges`). This is
how diagnostics underline code and how inline annotations work:

```
declare-option range-specs my_diags
set-option window my_diags %val{timestamp} '1.1,1.3|DiagnosticError'
add-highlighter window/ ranges my_diags
```

Both `line-specs` and `range-specs` are updated by `update-option` to follow buffer
edits since their timestamp — essential for async tools whose results arrive after
the user has kept typing.

### `completions` — feed insert-mode completion

`<line>.<column>[+<len>]@<timestamp>` header, then `<text>|<select cmd>|<menu text>`
candidates. Register it by adding `option=<name>` to the `completers` option. See
`tool-plugin-pattern.md` and `ctags.kak`/`clang.kak`.

## Built-in options you'll set or read

- Indentation/format: `tabstop`, `indentwidth` (0 = use a tab), `aligntab`,
  `eolformat` (lf/crlf), `finaleol`, `BOM`, `writemethod`.
- Editing/words: `extra_word_chars` (set on the **buffer**, not window, for word
  completion to see them — `kakrc.kak` adds `_ -`), `matching_pairs`, `static_words`.
- Completion/idle: `completers` (e.g. `filename word=all option=foo`),
  `autocomplete`, `idle_timeout`, `autoinfo`.
- Filetype/behavior: `filetype` (drives every filetype hook), `disabled_hooks`,
  `path` (for `gf`), `comment_line`/`comment_block_begin`/`comment_block_end` (from
  `comment.kak`), `modelinefmt`, `ui_options`.
- Integration conventions (declared by tool scripts): `makecmd`, `grepcmd`,
  `formatcmd`, `lintcmd`, `toolsclient`, `jumpclient`, `docsclient`,
  `windowing_module`.

## Conventions

- Prefix plugin options with the script name; separate words with **underscores**
  (so `$kak_opt_*` shell vars are valid identifiers): `comment_line`,
  `ctags_min_chars`.
- `-docstring` everything user-facing; `-hidden` everything internal.
- React to an option change with a `BufSetOption`/`WinSetOption` hook rather than
  polling. The `filetype` option is the canonical activation trigger.
- `set-option window …` for view-local behavior; `buffer` for buffer-wide; reserve
  `global` for genuine defaults. Some options (`BOM`, `eolformat`, `readonly`)
  ignore the window scope by design.
