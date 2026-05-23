# Defining commands, completion, aliases, and the helper commands

Reference: `:doc commands` (interactive; read the same content on disk at
`<prefix>/share/kak/doc/commands.asciidoc` — see SKILL.md for the prefix).
This covers how you expose functionality; how it runs is
in `execution-model.md`.

## `define-command`

```
define-command [switches] <name> <commands>
```

Switches:

- `-params <n>` — argument arity. `<n>` is a number or a range `min..max`, with
  either side omittable: `-params 1`, `-params 1..`, `-params ..1`, `-params 2..`.
  Arguments are then available as `%arg{1}`, `%arg{2}`, `%arg{@}` (and `$1`, `$@`
  in `%sh{}`). Without `-params`, the command takes none.
- `-docstring <text>` — shown in completion/help. **Required for non-hidden
  commands** by upstream convention. Multi-line is normal; the first line is
  typically `name <args>: one-line summary`.
- `-hidden` — keep it out of command-name completion. Use for internal helpers
  (e.g. the per-filetype `*-indent-on-new-line` commands).
- `-override` — allow replacing an existing command of the same name. Needed when a
  script may be sourced twice; otherwise redefining errors.
- Completion switches (`-shell-script-candidates`, `-file-completion`, …) still work
  but are discouraged in favor of `complete-command` (below) — except
  `-shell-script-candidates`/`-shell-script-completion`, which are still used inline
  upstream because they carry a script argument.

Canonical shape:

```
define-command my-thing -params 1.. -docstring %{
    my-thing <arg>...: do the thing to each <arg>
} %{
    evaluate-commands %sh{
        # build kakscript from the args ($@) and Kakoune state ($kak_*)
        ...
    }
}
```

### Validate inputs early

Fail loudly with a clear message before doing work. The upstream idiom checks an
option and emits a `fail`:

```
evaluate-commands %sh{
    if [ -z "${kak_opt_formatcmd}" ]; then
        echo "fail 'The option ''formatcmd'' must be set'"
    fi
}
```

## Completion: `complete-command`

```
complete-command [-menu] <name> <type> [<param>]
```

`<type>` ∈ `file | client | buffer | command | shell | shell-script |
shell-script-candidates`. `-menu` makes the generated candidates the *only* allowed
values and auto-selects the best one.

- `file`/`buffer`/`client`/`command`/`shell` — built-in completers. Example:
  `complete-command grep file`, `complete-command -menu new command`.
- `shell-script-candidates` — your `<param>` shell script prints one candidate per
  line **once** per completion session; results are cached and fuzzy-matched by
  Kakoune. Env: `$kak_token_to_complete` (0-based), `$kak_pos_in_token`. Best for
  list-from-disk completions (tags, subcommands). See `ctags.kak`, `git.kak`.
- `shell-script-completion` — script runs after **every** keypress; use only when
  candidates depend on what's typed so far.

## Aliases

```
alias <scope> <name> <command>
unalias <scope> <name> [<expected>]
```

Aliases are scoped, so a buffer can repoint a generic verb at a specialized command
— the basis of the `jump` pattern: a `*grep*` buffer aliases `jump` to its own
jumper. Common in interactive use because they're short (`reg` → `set-register`).
`unalias` with `<expected>` only removes it if it still equals that value (safe
teardown).

## Helper commands you script with

| Command                                                                    | Use                                                                                                                     |
|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| `try <cmds> [catch <on-error>]…`                                           | swallow/branch on errors; the engine's `if/else`. `%val{error}` holds the message in a catch. Multiple `catch` chain.   |
| `fail <text>`                                                              | raise an error with a message (aborts the current command run).                                                         |
| `nop`                                                                      | do nothing, but still evaluate arguments — `nop %sh{ … }` for side-effect-only shell.                                   |
| `echo [-markup] [-debug] [-to-file f] [-quoting q] <text>`                 | status line; `-debug` → `*debug*`; `-markup` enables `{Face}` tags.                                                     |
| `info [-anchor l.c] [-style …] [-title t] [-markup] <text>`                | popup box. Styles: `menu`, `above`, `below`, `modal`. `info -style modal` with no text hides a modal box.               |
| `prompt [-init s] [-on-change c] [-on-abort c] [-password] <prompt> <cmd>` | ask for a line; result in `%val{text}` / `$kak_text`.                                                                   |
| `on-key <cmd>`                                                             | wait for one key; it's in `%val{key}` / `$kak_key`.                                                                     |
| `menu [-auto-single] [-select-cmds] <title> <cmd> …`                       | choosable list; pairs of title+command (triples with `-select-cmds`). `-auto-single` runs immediately if only one item. |
| `set-register <name> <contents>…`                                          | each arg becomes one entry (registers are lists).                                                                       |
| `select <desc>…`                                                           | replace selections from `a.b,c.d` descriptors.                                                                          |
| `debug {info,buffers,options,faces,mappings,…}`                            | dump state to `*debug*`.                                                                                                |

`prompt`, `on-key`, and `info` act on the **current client**, so inside a draft
context (`evaluate-commands -draft`) they are invisible/inert unless driven by an
`execute-keys` in that same context — a frequent surprise.

## `try` as control flow (the central idiom)

There is no `if`. You combine `try` with a key/command that errors when a condition
fails. Most often that's `execute-keys` with `<a-k>`/`<a-K>` (keep / keep-not
selections matching a regex), which raises an error when it would leave zero
selections:

```
# "if previous line ends with { or (, indent the new line"
try %{ execute-keys -draft k x <a-k>[{(]\h*$<ret> j <a-gt> }

# if / else:
try %{
    execute-keys -draft <a-?>/\*<ret> <a-K>^\h*[^/*\h]<ret>   # condition
    # then-branch (implicit: condition matched without error)
} catch %{
    # else-branch
}
```

`fail` inside `try` is how you bail out of a branch deliberately.
