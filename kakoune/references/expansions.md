# Expansions and the shell bridge

Expansions inject Kakoune state into a command line. They run only when
unquoted or inside `"…"` (see `command-parsing-and-quoting.md`).
Authoritative list: `:doc expansions` (interactive; read the same content on
disk at `<prefix>/share/kak/doc/expansions.asciidoc` — see SKILL.md for the
prefix).

## The expansion types

| Type                  | Expands to                                         | Notes                                                |
|-----------------------|----------------------------------------------------|------------------------------------------------------|
| `%val{x}`             | engine value not stored in an option/register      | e.g. `%val{client}`, `%val{selection}`, `%val{cursor_line}`; some need a context (window/hook) |
| `%opt{x}`             | the option `x` in the current scope                | `%opt{filetype}`                                     |
| `%reg{x}`             | contents of register `x`                           | symbol or alphabetic name: `%reg{/}` = `%reg{slash}` |
| `%arg{n}` / `%arg{@}` | command argument n / all args                      | only inside a `define-command` body                  |
| `%sh{ … }`            | stdout of running the body as a POSIX shell script | blocks input until done; see below                   |
| `%file{path}`         | the contents of a host file                        | `set-register a %file{/etc/hosts}`                   |
| `%exp{ … }`           | its content, expanded like a `"…"` string          | for composing strings from several expansions        |

Lists expand to multiple words **only** when they are semantically lists
(`str-list` options, registers with several entries, `%val{selections}`). Unlike
the shell, an expansion never accidentally word-splits on whitespace, so you do not
need to wrap expansions in quotes for safety — quote only to group with other text.

## `%sh{ }`: the shell bridge

The body is a verbatim `%`-string handed to `/bin/sh`. Kakoune expansions do **not**
run inside it; instead Kakoune exports the values you *mention* as environment
variables. Mapping:

| kakscript             | shell env var                                                      |
|-----------------------|--------------------------------------------------------------------|
| `%val{x}`             | `$kak_x` (e.g. `$kak_session`, `$kak_buffile`, `$kak_cursor_line`) |
| `%opt{x}`             | `$kak_opt_x`                                                       |
| `%reg{x}`             | `$kak_reg_x` (all entries) / `$kak_main_reg_x` (main only)         |
| `%arg{n}` / `%arg{@}` | `$n` / `$@` (args are passed to the shell automatically)           |
| quoted list form      | `$kak_quoted_<thing>` — shell-safe, re-split with `eval set --`    |

**Only variables actually referenced are exported.** A variable named only inside a
comment still counts, which is the documented way to force-export one you build
indirectly:

```
echo %sh{ env | grep ^kak_ # kak_session }   # comment makes $kak_session available
```

### Reading list-valued state safely

Whitespace-containing list elements must come through the `$kak_quoted_*` form and
be re-split with `eval set --`:

```
eval set -- "$kak_quoted_selections"
while [ $# -gt 0 ]; do
    # work with "$1"
    shift
done
```

This is the canonical idiom (used by `c-family.kak`, `lint.kak`, …); see
`shell-and-portability.md` for the `for`-loop form and the emit-side `kakquote`
helper. Never iterate `$kak_selections` directly when elements may contain spaces or
newlines.

### Two ways to run shell, and when to use each

```
evaluate-commands %sh{ … }   # stdout is parsed and run as kakscript
nop %sh{ … }                 # stdout is discarded; use for pure side effects
echo %sh{ … }                # stdout shown in the status line
```

`evaluate-commands %sh{ … }` is the workhorse: the shell *prints kakscript* and
Kakoune runs it. Anything written to **stderr** lands in `*debug*` — invaluable for
debugging, but never write your kakscript output to stderr.

### Passing data INTO the shell without quoting hell

Stuffing option/selection text straight into a `%sh{}` body risks breaking the
surrounding kakscript quoting. The robust pattern is to park values in registers
first and read them as `$kak_reg_*` (from `make.kak`/`grep.kak`):

```
evaluate-commands -save-regs m %{
    set-register m %opt{makecmd}
    fifo -name *make* -script %{
        eval "$kak_reg_m \"\$@\""   # makecmd text arrives as $kak_reg_m, untouched
    } -- %arg{@}
}
```

### Returning data, and interleaving shell ↔ Kakoune mid-block

Inside `%sh{}` two named pipes are available:

- `$kak_command_fifo` — write kakscript to it; Kakoune runs it when the fifo closes.
  Lets you push commands without ending the `%sh{}`.
- `$kak_response_fifo` — ask Kakoune for data and read it back:

```
%sh{
    # ask Kakoune to write the whole buffer to the response fifo, then read it back
    echo "write $kak_response_fifo" > $kak_command_fifo
    content=$(cat $kak_response_fifo)   # buffer text — not available via any $kak_* var
}
```

These also bypass the OS environment-size limit for large payloads. `format.kak`
uses `$kak_command_fifo` to report a formatter error back without aborting.

## `%val` values worth knowing (full list in `:doc expansions`)

- Identity/context: `session`, `client`, `client_list`, `config`, `runtime`,
  `version`.
- Buffer: `bufname`, `buffile`, `buflist`, `buf_line_count`, `timestamp`,
  `history_id`, `modified`.
- Selection/cursor (window scope): `selection`, `selections` (quoted list),
  `selection_desc`, `selections_desc`, `cursor_line`, `cursor_column`
  (1-based byte), `cursor_char_column`, `selection_count`, `selection_length`.
- Hook context: `hook_param`, `hook_param_capture_N` (also `$kak_hook_param*` in
  shell) — the filtering-regex match and its capture groups.
- Prompt/key helpers: `text` (inside `prompt`), `key` (inside `on-key`), `count`
  and `register` (inside a `map` right-hand side or object menu), `error` (inside
  a `try … catch`).
- Source: `source` — path of the `.kak` file currently being `source`d, for
  loading sibling files relative to yourself.

`%val{selection_desc}` format is `anchor_line.anchor_col,cursor_line.cursor_col`
(1-based, byte columns) — the same format `select` consumes, so you can round-trip
selections through the shell.

## Gotchas

- `%sh{}` blocks input until it finishes **and** until its stdout/stderr close.
  Background work must redirect and detach: `{ long_job; } >/dev/null 2>&1 </dev/null &`.
  See `shell-and-portability.md` for the async pattern.
- You cannot nest a `%val{}` inside a `%sh{}` (it's verbatim) — use `$kak_*`.
- `%opt{}` of a missing option, or a `%val{}` outside its required context, errors —
  wrap in `try` if it may be absent.
