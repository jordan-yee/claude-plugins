# The filetype plugin pattern

Synthesized from Kakoune's `rc/filetype/*.kak`. Every filetype script follows the
same skeleton; they differ only in *how many* optional refinements they add. Pair
with `highlighters-and-faces.md`, `hooks.md`, and `execution-model.md`.

Contents:

- The canonical skeleton — the four parts every filetype has
- The highlighter body
- The refinement ladder, rungs 0–6 — add only what the language needs
- Module aliasing — one implementation, several filetypes
- Checklist for a new filetype

A complete, runnable version of this skeleton is in
`../assets/example-filetype.kak` — copy it as a starting point.

## The canonical skeleton (every filetype has these four parts)

```
# http://lang-homepage
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

# 1. Detection ─ map filenames to the filetype option
hook global BufCreate .*\.(ext|ext2) %{
    set-option buffer filetype mylang
}

# 2. Initialization ─ on activation: load module, set options, install hooks, arrange teardown
hook global WinSetOption filetype=mylang %{
    require-module mylang
    set-option window static_words %opt{mylang_static_words}

    hook window ModeChange pop:insert:.* -group mylang-trim-indent mylang-trim-indent
    hook window InsertChar \n -group mylang-indent mylang-indent-on-new-line

    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window mylang-.+ }
}

# 3. Highlight activation ─ attach the shared highlighter, remove it on change
hook -group mylang-highlight global WinSetOption filetype=mylang %{
    add-highlighter window/mylang ref mylang
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/mylang }
}

# 4. The module ─ defined once, evaluated lazily on first require-module
provide-module mylang %§

    # highlighters in the shared scope (see below)
    add-highlighter shared/mylang regions
    add-highlighter shared/mylang/code default-region group
    # … regions and regex highlighters …

    # keyword lists → completion + highlighting (shell join helper)
    evaluate-commands %sh{ … declare-option str-list mylang_static_words … }

    # the -hidden indent/insert commands referenced by the hooks above
    define-command -hidden mylang-trim-indent %{ … }
    define-command -hidden mylang-indent-on-new-line %{ … }

§
```

Why this shape:

- **Detection is `global BufCreate`** matching a filename regex; it only sets
  `filetype`. Keep detection separate from behavior so `file.kak`/`modeline.kak`/
  user config can also set `filetype` and trigger everything else.
- **Behavior hangs off `WinSetOption filetype=…`,** not off detection — so it
  activates however the filetype got set, and per *window*.
- **`require-module` makes activation lazy:** the heavy highlighter/command
  definitions in `provide-module` are evaluated only the first time the filetype is
  actually used, once per session.
- **Highlighters live in `shared/` and attach via `ref`,** so all windows of the
  filetype share one highlighter tree.
- **Every hook/highlighter is `-group`ed and torn down** on the next filetype change
  (the `-once -always … filetype=.*` line). This is the single most important
  correctness rule — without it, indentation and highlighting leak into the next
  file opened in that window.

## The highlighter body

Use a `regions` root so strings/comments don't get keyword-highlighted, with `code`
as the `default-region`:

```
add-highlighter shared/mylang regions
add-highlighter shared/mylang/code default-region group
add-highlighter shared/mylang/string  region '"' (?<!\\)(\\\\)*"  fill string
add-highlighter shared/mylang/comment region '//' '$'            fill comment
add-highlighter shared/mylang/code/keywords regex \b(if|else|fn)\b 0:keyword
add-highlighter shared/mylang/code/numbers  regex \b\d+\b 0:value
```

Build keyword highlighters and `static_words` from one shell block so the grammar
is declared in a single place — the `join`-helper idiom is shown in
`highlighters-and-faces.md`, with a full runnable version in
`../assets/example-filetype.kak`.

Use **semantic faces** (`keyword`, `type`, `value`, `string`, `comment`, `meta`,
`function`, `module`, `attribute`, `operator`, `documentation`) so colorschemes
control the look.

## The refinement ladder (add only what the language needs)

Different upstream filetypes sit at different rungs. Match the rung to the language.

### Rung 0 — trim + preserve indent (the floor; e.g. `toml.kak`)

```
define-command -hidden mylang-trim-indent %{
    try %{ execute-keys -draft -itersel x s \h+$ <ret> d }   # delete trailing whitespace
}
define-command -hidden mylang-indent-on-new-line %{
    evaluate-commands -draft -itersel %{
        try %{ execute-keys -draft <semicolon> K <a-&> }     # copy previous line's indent
        try %{ execute-keys -draft k : mylang-trim-indent <ret> }
    }
}
```

### Rung 1 — comment continuation on newline (e.g. `toml`, `kakrc`)

A separate `-hidden …-insert-on-new-line` command, hooked on `InsertChar \n`
alongside the indent command, that copies a comment prefix to the new line:

```
define-command -hidden mylang-insert-on-new-line %{
    evaluate-commands -draft -itersel %{
        # copy '#' comment prefix and following whitespace to the new line
        try %{ execute-keys -draft k x s ^\h*\K#\h* <ret> y gh j P }
    }
}
# hooked with its own group:
hook window InsertChar \n -group mylang-insert mylang-insert-on-new-line
```

Richer languages (`python`, `c-family`, `rust`) expand this into a multi-branch
`try`/`catch` that *continues* a non-empty comment but *deletes* an empty one — copy
that block from `python.kak` if you need it.

### Rung 2 — structural indent (indentation languages; e.g. `python.kak`)

Indent after a line ending in `:`, dedent a closing bracket typed alone:

```
# indent after a line ending with ':'
try %{ execute-keys -draft , k x <a-k> :$ <ret> <a-K> ^\h*# <ret> j <a-gt> }
# dedent a closing brace/bracket when it's first on the line
try %< execute-keys -draft x <a-k> ^\h*[}\]] <ret> gh / [}\]] <ret> m <a-S> 1<a-&> >
```

### Rung 3 — brace languages (e.g. `rust.kak`, `c-family.kak`)

Add `InsertChar` hooks for the relevant brackets and matching commands:

```
hook window InsertChar \{ -group mylang-indent mylang-indent-on-opening-curly-brace
hook window InsertChar [)}\]] -group mylang-indent mylang-indent-on-closing
```

- `…-indent-on-new-line`: indent after a line ending in `{`/`(`/`[`, align
  continuation lines to the opening bracket, dedent after single-line statements.
- `…-indent-on-opening-curly-brace` / `…-indent-on-closing`: realign a brace typed on
  its own line to its opener (`<a-h> <a-k> ^\h*[)}\]]$ <ret> h m <a-S> 1<a-&>`).

These get intricate; `c-family.kak` is the reference implementation and `rust.kak`
the modern one. Adapt rather than invent — the key building blocks are `<a-gt>`/
`<a-lt>` (indent/dedent), `<a-&>`/`1<a-&>` (align/copy-indent to selection), `m` (go
to matching bracket), `<a-k>`/`<a-K>` guards, all inside `-draft -itersel` + `try`.

### Rung 4 — block-comment star continuation (C/Rust/Java family)

The `/* … * … */` "add a leading `*` on each new line, align it, close on empty
line" logic. It's identical across `c-family.kak` and `rust.kak` — lift it verbatim.

### Rung 5 — embedded languages (e.g. `markdown.kak`, `kakrc.kak`)

Reference another filetype's highlighter inside a region:

```
# static embedding (kakrc embeds sh):
require-module sh
add-highlighter shared/mylang/shell region -recurse '\{' '%sh\{' '\}' ref sh

# dynamic embedding (markdown loads the fenced language lazily):
require-module %val{selection}
add-highlighter "shared/mylang/code/%val{selection}" region … ref %val{selection}
```

Wrap optional embeds in `try %{ require-module html; … }` so a missing language
doesn't break the file.

### Rung 6 — language-specific commands (e.g. `c-family.kak`)

Non-hidden, documented commands beyond indentation: `c-alternative-file` (jump
header↔source), include-guard insertion on `BufNewFile`, etc. Prefix with the
language, give a `-docstring`, and register any extra hooks with the same cleanup
discipline.

## Module aliasing (one implementation, several filetypes)

When several filetypes share an implementation (C/C++/ObjC), put the code in one
module and alias the others to it (`c-family.kak`):

```
provide-module c %{ require-module c-family }
provide-module cpp %{ require-module c-family }
```

## Checklist for a new filetype

- [ ] `BufCreate` detection sets only `filetype`.
- [ ] `WinSetOption filetype=…` does `require-module`, sets `static_words`, installs
      `-group`ed hooks, and ends with the `-once -always … filetype=.*` teardown.
- [ ] Highlighters defined in `shared/<lang>`; window attaches via `ref` with its own
      cleanup hook.
- [ ] Grammar + `static_words` declared once via a shell `join` block.
- [ ] Indent/insert commands are `-hidden`, run in `-draft -itersel`, guarded by
      `try`.
- [ ] You added only the rungs the language needs — don't bolt brace logic onto an
      indentation language.
