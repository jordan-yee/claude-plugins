# Execution model: evaluate-commands, execute-keys, and draft contexts

How code actually runs. Reference: `:doc execeval` (interactive; read the same
content on disk at `<prefix>/share/kak/doc/execeval.asciidoc` — see SKILL.md for the
prefix), and `doc/pages/autoedit.asciidoc` (source tree only, not installed) for the
indentation-hook reasoning that this model is built for.

## `evaluate-commands` vs `execute-keys`

- `evaluate-commands <cmds>` (alias `eval`) — run kakscript commands, as if typed at
  `:`. Use it to **group commands** under one set of switches/context, or to run the
  output of a `%sh{}`.
- `execute-keys <keys>` (alias `exec`) — feed normal/insert-mode **keys**, as if
  pressed. This is how you perform edits, selections, and movements from a script,
  because normal mode *is* the editing language (there is no `delete-line` command —
  you press `x` then `d`).

Multiple key arguments to `execute-keys` are concatenated (spaces between args are
ignored), so you can break a long key sequence across whitespace for readability;
use `<space>` or a quoted `" "` when you actually need a space key.

## Switches shared by both

| Switch                                   | Effect                                                                                                                                           |
|------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| `-draft`                                 | run in a **copy** of the context — selection/input changes are discarded. The cornerstone of non-destructive editing.                            |
| `-itersel`                               | run once per selection, each in its own context; prevents selections merging.                                                                    |
| `-save-regs <regs>`                      | save and restore the named registers around execution. (`execute-keys` already auto-saves `/ " \| ^ @ :` unless you override with `-save-regs`.) |
| `-client <names>` / `-try-client <name>` | run in the context of other client(s). `-try-client` falls back to the current context if the named client doesn't exist.                        |
| `-buffer <names>`                        | run once per named buffer. `*` = all non-debug buffers.                                                                                          |

Note: the `|` in the `-save-regs` row is escaped (`\|`) so it isn't parsed as a column break.

`evaluate-commands`-only:

- `-no-hooks` — suppress hooks during execution (e.g. so your edits don't retrigger
  indent hooks).
- `-verbatim` — forward positional args exactly, without re-parsing/splitting. Use
  when passing user data straight to a command: `evaluate-commands -verbatim -- edit
  -existing -- %reg{a}`.

`execute-keys`-only: `-with-hooks` (let keys trigger hooks), `-with-maps` (honor
user mappings instead of built-ins).

## The draft pattern (read `doc/autoedit.asciidoc`)

Editing from a hook/command must not move the user's cursor. So you operate on a
draft copy. The classic "preserve previous indentation on newline":

```
hook window InsertChar \n -group demo-indent %{
    try %{ execute-keys -draft k x s^\h+<ret>y j<a-h>P }
}
```

(`k` previous line, `x` select it, `s^\h+<ret>` select its leading blanks, `y` yank,
`j<a-h>` go to the new line's start, `P` paste before. Modern rc scripts use `x` for
line selection where the older `doc/autoedit.asciidoc` shows `<a-x>`.)

Build these incrementally:

1. Write the normal-mode keys that perform the edit interactively.
2. Wrap in `execute-keys -draft` so it runs on a copy (user's selection untouched).
3. Add `-itersel` if it must run independently per selection.
4. Wrap in `try` so that when a guard key (`<a-k>`, `s`, …) finds nothing and
   errors, the hook quietly does nothing instead of logging to `*debug*`.

`<a-k>regex<ret>` / `<a-K>regex<ret>` (keep / keep-not matching) are your conditions:
they error when the result would be empty, and `try` turns that error into a clean
"branch not taken." This is the entire vocabulary behind `c-family-indent-on-newline`
and friends — there is no special indentation engine, just keys + `try`.

## Local scope

Each `evaluate-commands` and each `define-command` body injects a fresh `local`
scope on top of `window`/`buffer`/`global` for its duration. Nested
`evaluate-commands` nest local scopes. Use it to override an option/alias
temporarily without leaking:

```
evaluate-commands %{ set local windowing_placement horizontal; terminal sh }
```

## Registers as scratch storage

Registers are lists of strings. Use them to carry data across a draft boundary or
into a `%sh{}` (`$kak_reg_x`):

```
evaluate-commands -save-regs a %{
    evaluate-commands -draft %{
        execute-keys ',xs^([^:\n]+):(\d+):(\d+)?<ret>'
        set-register a %reg{1} %reg{2} %reg{3}       # capture groups -> register a (a list)
    }
    edit -existing -- %reg{a}                          # use them after the draft
}
```

Always `-save-regs` registers you clobber so you don't disturb the user's yanks.
The capture groups `1`..`9` are populated by the last regex selection; `%reg{1}` etc.
read them.

## Putting it together: shell → kakscript → keys

A complete round trip: ask the shell to compute commands, run them, and have some of
them drive keys.

```
evaluate-commands %sh{
    # ... compute, then print kakscript to stdout ...
    printf 'set-option buffer foo %s\n' "$value"
    printf 'execute-keys %s\n' "<some-keys>"
}
```

Mind two parse boundaries: the shell's stdout is parsed as kakscript (so quote it
for kakscript), and any keys you print are parsed as keys when `execute-keys` runs.
