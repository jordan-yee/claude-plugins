# Example external-tool plugin — a complete, runnable template.
# Runs a shell command, streams its output into a *example* fifo buffer, and lets
# <ret> on an output line jump to file:line:col in the jump client.
# Modelled on rc/tools/make.kak, grep.kak, jump.kak, and fifo.kak;
# see references/tool-plugin-pattern.md.

# ── Configuration ─────────────────────────────────────────────────────────────
# Every tunable is an option with a -docstring and a default; users override it per
# buffer/window. Option words use underscores so $kak_opt_* is a valid shell
# identifier.
declare-option -docstring "shell command run by the example-run command" \
    str example_runcmd "grep -RHn"

declare-option -docstring "pattern used to highlight output lines: 1:file 2:line 3:column" \
    regex example_line_pattern "^([^:\n]+):(\d+):(\d+)?"

provide-module example %{

require-module fifo     # streams a command's output into a -fifo buffer and cleans up
require-module jump     # provides `jump`, `jump-next`, `jump-previous`, jump_current_line

define-command -params .. -docstring %{
    example-run [<arguments>]: run example_runcmd and stream its output to a buffer
    Extra arguments are forwarded to the command.
} example-run %{
    evaluate-commands -save-regs c %{
        set-register c %opt{example_runcmd}              # carry the command past quoting
        evaluate-commands -try-client %opt{toolsclient} %{
            fifo -scroll -name *example* -script %{
                trap - INT QUIT                          # restore default signals in the child
                eval "$kak_reg_c \"\$@\""                # run runcmd with the forwarded args ($@)
            } -- %arg{@}
            set-option buffer filetype example-output
            set-option buffer jump_current_line 0
        }
    }
}

# Highlight the output buffer: a shared tree attached per window via `ref` below.
add-highlighter shared/example-output group
add-highlighter shared/example-output/ regex "%opt{example_line_pattern}" 1:cyan 2:green 3:green
add-highlighter shared/example-output/ line '%opt{jump_current_line}' default+b

}

# ── Output-buffer activation ──────────────────────────────────────────────────
hook -group example-output-highlight global WinSetOption filetype=example-output %{
    add-highlighter window/example-output ref example-output
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/example-output }
}

hook global WinSetOption filetype=example-output %{
    # <ret> jumps to the file:line:col under the cursor in the jump client; the
    # generic `jump` (from jump.kak) parses that format.
    hook buffer -group example-output-hooks NormalKey <ret> jump
    hook -once -always window WinSetOption filetype=.* %{ remove-hooks buffer example-output-hooks }
}

# Step through results from any window.
define-command example-next     -docstring 'jump to the next example result'     %{ jump-next     *example* }
define-command example-previous -docstring 'jump to the previous example result' %{ jump-previous *example* }

# Lazy-load once, after user config is read.
hook -once global KakBegin .* %{ require-module example }
