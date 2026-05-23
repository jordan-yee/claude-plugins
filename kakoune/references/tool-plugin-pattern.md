# The external-tool plugin pattern

Synthesized from `rc/tools/*.kak` (make, grep, jump, fifo, format, comment, ctags,
lint, git, man, doc). Kakoune delegates real work — building, grepping, formatting,
linting, completion — to Unix tools and wires the results back in. Pair with
`shell-and-portability.md`, `defining-commands.md`, and `options.md`.

A complete, runnable version of this pattern is in `../assets/example-tool.kak` —
copy it as a starting point.

## Shape of a tool plugin

```
# user-facing configuration as options, with docstrings and sensible defaults
declare-option -docstring "shell command run to build the project" str makecmd make
declare-option -docstring "pattern matching error lines: 1:file 2:line 3:col 4:msg" \
    regex make_error_pattern "^([^:\n]+):(\d+):(?:(\d+):)? (?:fatal )?error:(\N+)?"

provide-module make %{
    require-module fifo       # declare dependencies up front
    require-module jump

    define-command -params .. -docstring %{
        make [<arguments>]: make utility wrapper
    } make %{
        … run the tool, route output to a buffer …
    }
    # highlighters / extra commands / filetype hooks for the output buffer
}

hook -once global KakBegin .* %{ require-module make }   # lazy-load on startup
```

Four conventions to copy:

- **Configuration is options, not hardcoded.** Each tunable is a `declare-option`
  with a `-docstring` and a default (`makecmd`, `grepcmd`, `formatcmd`, `lintcmd`).
  Users override per buffer/window.
- **Wrap the body in `provide-module`** and declare dependencies with
  `require-module` so load order is guaranteed.
- **Lazy-load with `hook -once global KakBegin .* %{ require-module … }`.** The plugin
  costs nothing until the session starts (and modules dedupe), versus running setup
  at source time.
- **Validate before working** (`defining-commands.md`): emit `fail '…'` from a shell guard if a
  required option is empty.

## Routing command output into a buffer: fifo + jump + toolsclient

The make/grep family streams a command's output into a scratch buffer asynchronously
and lets `<ret>` jump to the referenced source location. The pieces:

- **`toolsclient` / `jumpclient`** (declared in `jump.kak`): options naming which
  client shows tool output vs. receives source jumps. Route with
  `evaluate-commands -try-client %opt{toolsclient} %{ … }`.
- **`fifo`** (`require-module fifo`): runs a command and pipes its output into a
  `-fifo` buffer, cleaning up the temp fifo on `BufCloseFifo`. Pass the command as a
  `-script` and forward args after `--`:

```
evaluate-commands -save-regs m %{
    set-register m %opt{makecmd}                      # carry config past quoting
    evaluate-commands -try-client %opt{toolsclient} %{
        fifo -scroll -name *make* -script %{
            trap - INT QUIT
            eval "$kak_reg_m \"\$@\""                  # run makecmd with forwarded args
        } -- %arg{@}
        set-option buffer filetype make
        set-option buffer jump_current_line 0
    }
}
```

- **`jump`** (`require-module jump`): parses `file:line:col` from the current output
  line and opens it in `jumpclient`. Give the output buffer a `filetype`, then in a
  `WinSetOption filetype=<yours>` hook map `<ret>` to `jump` (or a specialized
  jumper) and alias `jump-next`/`jump-previous`:

```
hook global WinSetOption filetype=make %{
    alias buffer jump make-jump
    hook buffer -group make-hooks NormalKey <ret> make-jump
    hook -once -always window WinSetOption filetype=.* %{ remove-hooks buffer make-hooks }
}
```

Provide `<tool>-next`/`<tool>-previous` commands that call `jump-next *buffer*` so
users can step through results from anywhere.

## Filtering selections through a tool: the `|` register pattern

`format.kak` pipes each selection through `formatcmd` and reports errors without
aborting, using the `|` shell-filter register plus `$kak_command_fifo`:

```
evaluate-commands -draft -no-hooks -save-regs 'e|' %{
    set-register e nop
    set-register '|' %{
        in=$(mktemp …); out=$(mktemp …)
        cat > "$in"
        if eval "$kak_opt_formatcmd" < "$in" > "$out"; then
            cat "$out"
        else
            echo "set-register e fail formatter error" > "$kak_command_fifo"
            cat "$in"                                   # leave text unchanged on failure
        fi
        rm -f "$in" "$out"
    }
    execute-keys '|<ret>'                                # run the filter
    %reg{e}                                              # nop on success, fail on error
}
```

The `set-register e nop` + `%reg{e}` trick defers a possible error until after the
filter runs. `-no-hooks` stops your edit from retriggering format/indent hooks.

## Insert-mode completion from a tool

Two halves (see `options.md` `completions`, and `interfacing.asciidoc`):

1. Declare a hidden `completions` option and add it to `completers` for the relevant
   filetype:

```
declare-option -hidden completions tool_completions
hook global BufSetOption filetype=mylang %{
    set-option -add window completers option=tool_completions
}
```

2. On `InsertIdle`, run the completer **async** and write the `completions` value back
   via `kak -p` (so the editor never blocks):

```
nop %sh{ (
    header="${kak_cursor_line}.${kak_cursor_column}@${kak_timestamp}"
    candidates=$(run_completer …)                       # format: text|select|menu
    printf %s\\n "set-option buffer=${kak_bufname} tool_completions ${header} ${candidates}" \
        | kak -p "$kak_session"
) > /dev/null 2>&1 < /dev/null & }
```

For *command-argument* completion (not insert mode) use
`-shell-script-candidates` on the command (cached, fuzzy-matched) — see `ctags.kak`,
`git.kak`, and `defining-commands.md`.

## Diagnostics: gutter flags and inline ranges

Linters publish results into `line-specs` (gutter) and `range-specs` (underlines)
options, highlighted by `flag-lines`/`ranges` (see `options.md`,
`highlighters-and-faces.md`). The async linter writes those options back via
`kak -p`, setting the timestamp to `%val{timestamp}` and calling `update-option` so
marks track edits made while linting ran. `lint.kak` is the full reference (selection
offset math, error/warning counts, message-on-cursor).

## Info boxes and menus for tool UI

- `info -anchor <line>.<col> -style above '…'` shows context near the cursor
  (`ctags-funcinfo` signature popups; pair with `NormalIdle`/`InsertIdle` for
  autoinfo).
- `menu` (`require-module menu`) presents choices, e.g. multiple tag matches:
  `menu -auto-single 'item: info' 'edit … ; execute-keys …' …`. Build menu entries in
  the shell, escaping with care (see `menu.kak`/`ctags.kak` for the escaping of
  `!&#|` in generated entries).

## Checklist for a tool plugin

- [ ] Tunables are `declare-option … -docstring` with defaults; prefixed by script
      name.
- [ ] Body wrapped in `provide-module`, dependencies via `require-module`, lazy-loaded
      with a `KakBegin` `require-module`.
- [ ] Shell is POSIX; values cross the boundary via registers/`$kak_quoted_*`/
      `kakquote`.
- [ ] Slow work is detached (`( … ) >/dev/null 2>&1 </dev/null &`) and reports back
      with `kak -p "$kak_session"`.
- [ ] Output buffers get a `filetype`, highlighters, and `-group`ed hooks/maps with
      teardown.
- [ ] Errors surface via `fail`/`echo`/`*debug*`, never silently.
