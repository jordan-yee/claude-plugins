# Hooks

Hooks run commands on editor events. Reference: `:doc hooks` (interactive; read the
same content on disk at `<prefix>/share/kak/doc/hooks.asciidoc` — see SKILL.md for
the prefix). They are the backbone of filetype activation, indentation, and
reacting to option changes.

```
hook [switches] <scope> <hook_name> <filtering_regex> <commands>
```

- `<scope>` — `global`, `buffer`, or `window` (see scopes in `SKILL.md`). Pick the
  **narrowest** scope that works. Detection hooks are usually `global`; behavior for
  one file's view is `window`; behavior tied to a buffer is `buffer`.
- `<filtering_regex>` — must match the **entire** hook parameter string for the
  commands to run. For events with no parameter, use `''`.
- `<commands>` — runs with `%val{hook_param}` (and `%val{hook_param_capture_N}` /
  `$kak_hook_param`, `$kak_hook_param_capture_N`) available.

## Switches

- `-group <name>` — tag the hook so `remove-hooks <scope> <group>` (group matched as
  a regex) can remove it later, and so `disabled_hooks` can target it. **Use a group
  for every hook a plugin installs.**
- `-once` — auto-remove after it fires once.
- `-always` — run even when hooks are disabled (`\` prefix, `-no-hooks`,
  `disabled_hooks`). Reserve for cleanup that must not be skipped (e.g.
  `BufCloseFifo` temp-file removal).

## The cleanup discipline (most important convention)

Hooks/highlighters/maps you add for a filetype must be removed when the filetype or
window changes, or they leak across buffers. The upstream idiom registers a
self-removing teardown in the same activation hook:

```
hook global WinSetOption filetype=rust %{
    require-module rust
    hook window InsertChar \n -group rust-indent rust-indent-on-new-line
    hook window ModeChange pop:insert:.* -group rust-trim-indent rust-trim-indent
    # tear everything down on the next filetype change for this window:
    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window rust-.+ }
}
```

- One `-group <ft>-…` per concern (`rust-indent`, `rust-trim-indent`,
  `rust-highlight`) so groups can be removed by the `rust-.+` regex.
- The teardown is `-once -always window WinSetOption filetype=.*` — fires on the
  *next* filetype set, exactly once, even if hooks are disabled.
- Highlighters use the same shape with `remove-highlighter` (see
  `highlighters-and-faces.md`).

## Hook catalog (the ones you'll actually use)

Editing/insertion:

- `InsertChar <char>` — a char was inserted. Drives indentation: hook on `\n`,
  `\{`, `\}`, etc. Param is the char.
- `InsertDelete <char>`, `InsertMove <key>`, `InsertKey <key>`, `InsertIdle`,
  `NormalKey <key>`, `NormalIdle` — the idle hooks fire after `idle_timeout` ms with
  no input (used for autocompletion, lazy syntax loading, autoinfo).
- `ModeChange <push|pop>:<old>:<new>` — entering/leaving a mode. The trim-indent
  hooks use `ModeChange pop:insert:.*` to clean up when leaving insert mode.

Buffers/files:

- `BufCreate <name>`, `BufNewFile <file>`, `BufOpenFile <file>` — buffer/file
  creation. **Filetype detection** hooks on `BufCreate` matching a filename regex.
- `BufSetOption <name>=<value>` — an option changed on a buffer. The `comment.kak`
  pattern hooks `BufSetOption filetype=…` to set per-language options.
- `BufWritePre`/`BufWritePost <file>`, `BufReload`, `BufClose` — save/reload/close.
- `BufOpenFifo`, `BufReadFifo <range>`, `BufCloseFifo` — fifo-buffer lifecycle.

Options/windows:

- `WinSetOption <name>=<value>` — **the filetype activation hook**:
  `WinSetOption filetype=rust`. Runs in a draft context, so don't expect selection
  changes to stick.
- `GlobalSetOption`, `BufSetOption` — same for global/buffer scope.
- `WinCreate`, `WinClose`, `WinDisplay <buf>`, `WinResize` — window lifecycle (draft
  context).

Session/misc:

- `KakBegin <session>` — after user config is read. **Lazy module load** hooks here:
  `hook -once global KakBegin .* %{ require-module make }`.
- `KakEnd` — quitting.
- `User <param>` — fired by `trigger-user-hook <param>`; lets plugins define their
  own events. `ModuleLoaded <module>` fires after a module first loads.
- `RawKey <key>` — every keypress regardless of mode/mappings; cannot be triggered
  by `execute-keys`.

The full list (with parameter formats and scope caveats) is in `:doc hooks`. Note
some hooks ignore the `window` scope (e.g. `BufWritePost` is a buffer event).

## Capture groups in the filter

Name your filetype family with a capture so one hook serves several types
(`c-family.kak`):

```
hook global WinSetOption filetype=(c|cpp|objc) %[
    require-module c-family
    hook -group "%val{hook_param_capture_1}-indent" window InsertChar \n c-family-indent-on-newline
    hook -once -always window WinSetOption filetype=.* "remove-hooks window %val{hook_param_capture_1}-.+"
]
```

## Triggering and disabling

- `trigger-user-hook <param>` fires `User` hooks whose filter matches `<param>`.
- Disable temporarily: `\` before a normal-mode command, or `-no-hooks` on
  `evaluate-commands`/`execute-keys`.
- Disable by pattern: `set-option … disabled_hooks <regex>` (e.g. `.*-indent` to turn
  off all indentation hooks). `-always` hooks ignore all of this.

## Footguns

- A filter regex must match the **whole** param. `filetype=c` won't match a param of
  `filetype=cpp`; use `filetype=(c|cpp)` or `filetype=c.*` deliberately.
- `WinSetOption`/`WinCreate` run in a draft context — perform option/highlighter/map
  changes there, not selection edits.
- Forgetting `-group` means you can't clean up; forgetting the teardown hook means
  behavior bleeds into the next filetype opened in that window.
