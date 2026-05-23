# Debugging and the development loop

Kakoune ships no unit-test harness for configuration — you confirm behaviour by
running it and watching the editor's own introspection. This file collects the
whole loop; the shell-specific traps stay in `shell-and-portability.md`.

## Read the live docs first

`:doc <topic>` inside Kakoune (e.g. `:doc expansions`, `:doc highlighters`) is the
authoritative reference and always matches the *installed* version — trust it over
memory for exact switch names and `%val` availability. `:doc` is interactive (it opens
a buffer in a running Kakoune); the same text is installed on disk as plain asciidoc,
readable directly, at `<prefix>/share/kak/doc/<topic>.asciidoc`. The prefix matches
the `kak` binary (`/usr/local/bin/kak` → `/usr/local/share/kak/doc/`) and equals
`%val{runtime}` in a session. (The Kakoune *source* tree keeps these — plus source-only pages — under
`doc/pages/`.)

## Watch the debug buffer

`:buffer *debug*` collects errors, hook failures, and anything a `%sh{}` block
writes to stderr. Make execution traceable:

- `echo -debug <text>` / `echo -debug %val{…}` — print to `*debug*` from a script
  without disturbing the status line.
- `set-option global debug 'hooks|shell|commands|keys'` — verbose logging of the
  named subsystems. Combine only the flags you need; `keys` in particular is noisy.

## Inspect current state

`:debug options`, `:debug buffers`, `:debug faces`, `:debug mappings` dump the live
values — the fastest way to see which scope an option resolved in, what faces a
colorscheme defined, or which hooks/maps are currently installed.

## Iterate without restarting

- `:source <file>` re-evaluates a script: enough for top-level commands, hooks, and
  highlighters during development.
- A `provide-module` body evaluates only **once**. To redefine it you need
  `provide-module -override` **before** the module has been required; once it has
  loaded, only a restart clears it. Plan reloads around this.
- `kak -n` starts a clean session that skips user config; `:source path/to/plugin.kak`
  then loads just your script in isolation. During heavy module development,
  restarting `kak -n` is often the fastest loop.

## Shell blocks specifically

`%sh{}` debugging has one extra trap: `evaluate-commands %sh{}` parses the block's
**stdout** as kakscript, so a stray diagnostic on stdout becomes a broken command.
Send diagnostics to **stderr** (which lands in `*debug*`). See the "Debugging shell
blocks" section of `shell-and-portability.md` for the `printf … >&2` idiom and
`set-option global debug 'shell'`.
