# Example filetype plugin — a complete, runnable template.
# Replace "example" and ".example" and the keyword lists with your language's.
# The structure mirrors rc/filetype/*.kak (toml.kak is the closest minimal model);
# see references/filetype-plugin-pattern.md for the refinement ladder it sits on.

# ── 1. Detection ──────────────────────────────────────────────────────────────
# Map filenames to the filetype option. Detection sets ONLY `filetype`, so the
# behaviour below also runs when a modeline or the user sets it by hand.
hook global BufCreate .*\.example %{
    set-option buffer filetype example
}

# ── 2. Initialization ─────────────────────────────────────────────────────────
# On activation: load the module, set options, install -group'ed hooks, and
# register the teardown that removes them on the next filetype change for this
# window (without it, indentation/insertion bleed into the next file you open).
hook global WinSetOption filetype=example %{
    require-module example

    set-option window static_words %opt{example_static_words}

    hook window ModeChange pop:insert:.* -group example-trim-indent example-trim-indent
    hook window InsertChar \n -group example-insert example-insert-on-new-line
    hook window InsertChar \n -group example-indent example-indent-on-new-line

    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window example-.+ }
}

# ── 3. Highlight activation ───────────────────────────────────────────────────
# Attach the shared highlighter per window; remove it on filetype change.
hook -group example-highlight global WinSetOption filetype=example %{
    add-highlighter window/example ref example
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/example }
}

# ── 4. The module ─────────────────────────────────────────────────────────────
# Defined once; its body runs lazily on the first `require-module example`.
provide-module example %{

    # Highlighters live in the shared scope so every window of this filetype shares
    # one tree. `code` is the default region; strings/comments are their own regions
    # so keywords inside them are not highlighted.
    add-highlighter shared/example regions
    add-highlighter shared/example/code    default-region group
    add-highlighter shared/example/string  region '"' (?<!\\)(\\\\)*" fill string
    add-highlighter shared/example/comment region '#' '$'            fill comment

    # Declare the grammar once: these lists feed both the keyword highlighters and
    # `static_words`. `join` builds `a|b|c` (regex) or `a b c` (static_words); it must
    # be defined inline (shell functions can't cross %sh{}). See
    # references/shell-and-portability.md.
    evaluate-commands %sh{
        keywords='if else for while return'
        types='int bool str'
        values='true false null'
        join() { sep=$2; eval set -- $1; IFS="$sep"; echo "$*"; }   # see shell-and-portability.md
        printf %s\\n "declare-option str-list example_static_words $(join "${keywords} ${types} ${values}" ' ')"
        printf %s "
            add-highlighter shared/example/code/keywords regex \b($(join "${keywords}" '|'))\b 0:keyword
            add-highlighter shared/example/code/types    regex \b($(join "${types}"    '|'))\b 0:type
            add-highlighter shared/example/code/values   regex \b($(join "${values}"   '|'))\b 0:value
        "
    }

    # Indentation/insertion commands are -hidden, operate on a DRAFT copy of the
    # selections (so the user's cursor is untouched), run once per selection with
    # -itersel, and are wrapped in `try` so a non-match is a clean no-op.
    define-command -hidden example-trim-indent %{
        # remove trailing whitespace
        try %{ execute-keys -draft -itersel x s \h+$ <ret> d }
    }

    define-command -hidden example-insert-on-new-line %{
        evaluate-commands -draft -itersel %{
            # continue a '#' comment prefix (and its trailing space) onto the new line
            try %{ execute-keys -draft k x s ^\h*\K#\h* <ret> y gh j P }
        }
    }

    define-command -hidden example-indent-on-new-line %{
        evaluate-commands -draft -itersel %{
            # copy the previous line's indentation onto the new line
            try %{ execute-keys -draft <semicolon> K <a-&> }
            # then strip any whitespace left on the now-blank previous line
            try %{ execute-keys -draft k : example-trim-indent <ret> }
        }
    }
}
