# Command parsing and quoting

Most "my hook does nothing" / "weird parse error" problems are a quoting mistake.
Source of truth: `:doc command-parsing` and `:doc expansions` (interactive; read the
same content on disk at `<prefix>/share/kak/doc/{command-parsing,expansions}.asciidoc`
— see SKILL.md for the prefix).

## How a line is parsed

- Commands are terminated by a newline or `;`. A literal semicolon argument must be
  escaped as `\;` (or written as the key name `<semicolon>` inside `map`/`execute-keys`).
- Words (the command name and its arguments) are separated by whitespace.
- The first word is the command; the rest are arguments. A leading `-` makes a word
  a switch; `--` stops switch parsing for the remaining words.

## The three string forms

A word that starts with one of these is a quoted string spanning whitespace:

| Form       | Inside it…                                                            | Escape the delimiter by…                   |
|------------|-----------------------------------------------------------------------|--------------------------------------------|
| `'single'` | nothing is processed — fully literal                                  | doubling: `''`                             |
| `"double"` | `%`-expansions ARE processed                                          | doubling: `""`, and `%%` for a literal `%` |
| `%X…X`     | content is verbatim (no expansion) unless `X`'s *type* says otherwise | depends on `X`, see below                  |

Key consequence: **expansions run when unquoted or inside `"…"`, but never inside
`'…'` or inside a `%{…}` string.**

```
echo %val{session}      # echoes the session id
echo "x%val{session}x"  # expands, surrounded by x
echo '%val{session}'    # literal text %val{session}
echo %{%val{session}}   # literal text %val{session}  (verbatim %-string)
echo x%val{session}x    # literal text x%val{session}x (expansion only at word start when unquoted)
```

## `%`-strings: nestable vs non-nestable delimiters

After `%` (and an optional alphabetic *expansion type*, see below) comes a single
punctuation delimiter that sets where the string ends.

**Nestable / balanced** — `(` `[` `{` `<` close with `)` `]` `}` `>`:

- The string ends at the *matching* close. Balanced inner pairs of the **same**
  bracket nest correctly; you do **not** (and cannot) escape them.
- Other bracket types inside need not balance.

```
%{foo}                 -> foo
%{foo {bar} baz}       -> foo {bar} baz     (inner {} balanced)
%{nest{ed} non[nested} -> nest{ed} non[nested
%{foo\{}               -> PARSE ERROR (unbalanced { } — the \ does not escape)
%[foo\{]               -> foo\{            (different delimiter, { needn't balance)
```

**Non-nestable** — any other punctuation (`|` `§` `~` `@` `!` `^` `,` `#` …):

- The string ends at the **next** occurrence of that character.
- Escape a literal delimiter by **doubling** it.

```
%|abc||def|  -> abc|def
%§a§§b§       -> a§b
```

There is nothing magic about which character you choose. `{}` is the default and
most common; everything else exists to avoid collisions with the body.

## Choosing a delimiter (the practical skill)

When the body contains the delimiter you'd normally use, switch to one it doesn't
contain. Upstream `rc/` scripts use the full range — `%{ }`, `%[ ]`, `%( )`,
`%< >`, `%| |`, `%§ §`, `%~ ~`, `%@ @`, and exotic single-byte-unlikely ones — and
**cascade a different delimiter at each nesting level** so inner strings never
prematurely close an outer one. From `rust.kak`:

```
define-command -hidden rust-indent-on-new-line %~      # level 1: ~
    evaluate-commands -draft -itersel %@               # level 2: @
        try %{                                         # level 3: {}
            try %[ … ] catch %[ … ]                    # level 4: [] (line- vs block-comment branches)
        }
    @
~
```

Guidelines that keep this readable and upstream-consistent:

- Default to `%{ }`. Reach for `%[ ]`, `%( )`, `%< >` next.
- Use `%{ }` (or another **balanced** pair) when the body is itself balanced
  kakscript (command bodies, hook bodies) — it tolerates nested braces.
- Use a **non-nestable** delimiter (`%| |`, `%§ §`, `%~ ~`, `%@ @`) when the body
  contains lone/unbalanced brackets or dense regex — there is no balance
  requirement, only "ends at next delimiter," and you can double to escape.
- `provide-module` bodies are large and full of brackets/regex; upstream commonly
  delimits them with `%§ … §` or `%{ … }`. Pick whatever the body doesn't contain.
- When generating kakscript that itself contains every common bracket (e.g.
  `menu.kak`), pick a rare delimiter like `§` and double literals (`s/§/§§/g`).

## Non-quoted words and backslash rules

For a bare word (no surrounding quote):

- A leading `\` before `%`, `'`, or `"` escapes that character so the word is *not*
  treated as a string start; the `\` is discarded. (`\%foo` is the literal `%foo`.)
- A `\` before whitespace or `;` makes that whitespace/`;` part of the word.
- Any other `\` is a literal backslash.

This is why regex literals are usually safer inside a `%{…}`/`'…'` than bare.

## Typed expansions (`%sh{}`, `%opt{}`, …)

Between the `%` and the delimiter you may put an alphabetic **expansion type**. The
quoting/escaping rules above are identical; the type only changes how the captured
content is used:

- empty (`%{…}`) — content used verbatim.
- `sh` `reg` `opt` `val` `arg` `file` — expanded as described in
  `expansions.md` / `:doc expansions`.
- `exp` — content is expanded like a double-quoted string (but `"` needn't be
  escaped); handy for building strings from several expansions, e.g.
  `add-highlighter %exp{window/%val{hook_param_capture_1}-ref-diff} ref diff`.
- any other letters — **parse error**.

## The verbatim-now / re-parsed-later rule

A `%{…}` argument is captured *verbatim* at the current parse. When that argument is
later **executed as commands** (a `define-command` body, a `hook` body, the right
side of `map`, the argument to `evaluate-commands`), it is parsed *again* from
scratch — and expansions inside it run *then*, in that execution context.

```
define-command show-client %{ echo %val{client} }
#                            ^ stored literally; %val{client} is NOT expanded here
show-client
#  -> body re-parsed now; %val{client} expands to the current client
```

Corollaries:

- Inside `define-command … %{ … }`, use `%val{}`/`%opt{}` directly — they resolve at
  call time. To capture a value at *definition* time instead, build the body with a
  surrounding `"…"` or `%exp{…}` so it expands once, up front.
- Inside `%sh{ … }` nothing kakscript-side expands (it's a verbatim `%`-string handed
  to the shell), so you must use `$kak_session`, `$kak_opt_x`, etc. See
  `expansions.md`.
- `evaluate-commands %sh{ … }` runs the shell, then **parses the shell's stdout as
  kakscript**. `nop %sh{ … }` runs the shell and discards stdout (use when the side
  effect is all you want). This "shell prints commands, Kakoune runs them" loop is
  the core extension mechanism.

## Quick self-check before you trust a string

- Does the body contain my delimiter unbalanced? → change delimiter.
- Do I want this expanded now or when it runs? → `"…"`/`%exp{}` = now (or per-run if
  re-parsed); `'…'`/`%{…}` = not at this parse.
- Am I in a `%sh{}`? → use `$kak_*`, not `%val{}`.
- Passing a regex? → prefer `%{…}` or `'…'` so backslashes survive.
