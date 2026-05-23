# Keys, mappings, and user modes

How to name keys, bind them, and build menus of commands. References: `:doc mapping`,
`:doc modes`, `:doc keys` (the full normal-mode command list) — interactive; read the
same content on disk at `<prefix>/share/kak/doc/{mapping,modes,keys}.asciidoc` (see
SKILL.md for the prefix).

## Key notation

Used in `map` and `execute-keys`:

- Plain keys represent themselves: `x`, `w`, `5`. Wrap for consistency: `<x>`.
- Modifiers: `<c-x>` Ctrl, `<a-x>` Alt, `<c-a-x>` Ctrl+Alt. Shift: `<s-x>` only for
  ASCII letters and special keys (`<s-tab>`, `<s-up>`); for letters just use the
  capital (`X`).
- Named keys: `<ret>` `<esc>` `<space>` `<tab>` `<backspace>` `<del>` `<up>`/`<down>`/
  `<left>`/`<right>` `<home>` `<end>` `<pageup>` `<pagedown>` `<ins>` `<F1>`..`<F12>`.
- Punctuation aliases that reduce escaping in scripts: `<lt>` `<gt>` (`<` `>`),
  `<plus>` `<minus>`, `<semicolon>`, `<percent>`, `<quote>` (`'`), `<dquote>` (`"`).
  Prefer `exec <percent>` over `exec \%`, and `<semicolon>` over `\;`.
- `<c-c>` and `<c-g>` cannot be remapped (they cancel). Some combos (`<c-s-a>`)
  can't be produced by terminals.

## `map` / `unmap`

```
map [-docstring <s>] <scope> <mode> <key> <keys>
unmap <scope> <mode> <key> [<expected>]
```

- `<scope>`: `global`/`buffer`/`window`.
- `<mode>`: `normal`, `insert`, `prompt`, `menu`, `user`, `goto`, `view`, `object`
  (the full set also includes `combine`).
- The right-hand `<keys>` are **not** affected by other mappings — they always do
  their built-in thing. Mappings only intercept the left-hand key.
- `<keys>` execute in the current mode's context, except `user`-mode mappings always
  run in a normal-mode context.
- `unmap` with `<expected>` only removes the binding if it still equals that
  sequence — the safe teardown form (mirror of `unalias`).

To run a command from a mapping, type the `:`-prompt keys:

```
map global user g ':git status<ret>' -docstring 'git status'
```

### Forwarding count and register

A normal-mode mapping can be prefixed by a count/register like any key; forward them
into your command with `%val{count}` / `%val{register}`:

```
map global normal = ':echo got count %val{count} reg %val{register}<ret>'
```

### Cleaning up buffer/window maps

Buffer- or window-scoped maps from a filetype need teardown, using `%exp{}` to bake
in the param and `%%{}` to defer the unmap's own expansion (from `git.kak`):

```
hook global WinSetOption filetype=(git-diff|git-log) %{
    map buffer normal <ret> %exp{:git-diff-goto-source # %val{hook_param}<ret>} -docstring 'jump to source'
    hook -once -always window WinSetOption filetype=.* %exp{
        unmap buffer normal <ret> %%{:git-diff-goto-source # %val{hook_param}<ret>}
    }
}
```

## Modes and user modes

Built-in modes: normal, insert, goto (`g`), view (`v`), object (`<a-i>`/`<a-a>`),
prompt (`:` `/`), user (`<space>`). The **user mode** is intentionally empty — bind
your shortcuts there to avoid shadowing built-ins.

For richer plugin menus, declare your own mode:

```
declare-user-mode mygit
map global mygit s ':git status<ret>' -docstring 'status'
map global mygit l ':git log<ret>'    -docstring 'log'
map global user  g ':enter-user-mode mygit<ret>' -docstring 'git…'
```

- `enter-user-mode <name>` activates it for the next key; `-lock` stays until `<esc>`.
- Docstrings show in the autoinfo box, making the mode self-documenting (set
  `autoinfo`).
- `ModeChange` hooks fire as modes push/pop; user modes appear as
  `next-key[user.<name>]`.

## `menu` for ad-hoc choices

When you don't need a persistent mode, `menu` (from `menu.kak`, `require-module
menu`) shows a one-shot chooser of title→command pairs:

```
menu -auto-single \
    'Status' 'git status' \
    'Log'    'git log'
```

`-auto-single` runs immediately if there's a single item; `-select-cmds` adds a
per-item command run on hover (commonly `info` documentation).
