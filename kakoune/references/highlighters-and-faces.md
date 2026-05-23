# Highlighters and faces

Highlighters change how text is displayed (syntax highlighting, gutters, whitespace,
matching). Faces are the color/attribute definitions they apply. References: `:doc
highlighters`, `:doc faces` (interactive; read the same content on disk at
`<prefix>/share/kak/doc/{highlighters,faces}.asciidoc` — see SKILL.md for the prefix).

```
add-highlighter [-override] <path>/<name> <type> <params>...
remove-highlighter <path>/<name>
```

`<path>` starts with a scope: `global`, `buffer`, `window`, or `shared`. Omitting
`<name>` (path ends in `/`) auto-generates one from the params.

## The shared + ref pattern (how filetype highlighting is built)

Define highlighters once in the **`shared`** scope, then attach them to a window with
`ref`. This shares the (often large) highlighter tree across every window of that
filetype instead of rebuilding it per window.

```
# in the module body — define once:
add-highlighter shared/mylang regions
add-highlighter shared/mylang/code default-region group
add-highlighter shared/mylang/code/keywords regex \b(if|else|fn)\b 0:keyword

# in the activation hook — attach per window, and remove on filetype change:
hook -group mylang-highlight global WinSetOption filetype=mylang %{
    add-highlighter window/mylang ref mylang
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/mylang }
}
```

`ref <name>` references any named highlighter in `shared/`. The teardown mirrors the
hook-cleanup discipline (see `hooks.md`).

## Regions: segmenting the buffer

A `regions` highlighter splits the buffer into differently-highlighted spans
(strings, comments, code). This is the heart of a syntax file.

```
add-highlighter shared/lang regions
add-highlighter shared/lang/string  region '"' (?<!\\)(\\\\)*"  fill string
add-highlighter shared/lang/comment region '//' '$'            fill comment
add-highlighter shared/lang/code    default-region group
add-highlighter shared/lang/code/keywords regex \b(if|else)\b 0:keyword
```

```
add-highlighter <path>/<name>/<region> region [-match-capture] [-recurse <re>] \
    <opening> <closing> <type> <params>...
```

- `<opening>`/`<closing>` are regexes for the region's start/end text.
- `default-region <type>` highlights everything not in another region — put `code`
  here as a `group`, then add `regex` highlighters under it.
- `-recurse <re>` allows nesting: each `<re>` match consumes one `<closing>`, so
  nested braces/comments don't end the region early. Block comments use
  `region -recurse /\* /\* \*/ …`; shell-in-kakrc uses `-recurse '\{'` to balance.
- `-match-capture` ties `closing`/`recurse` to capture 1 of `opening` — required for
  Rust raw strings (`r#"…"#`) and Markdown fences where the closer must match the
  opener's length. Pattern: `region -match-capture %{r(#*)"} %{"(#*)} fill string`.

Regions match left-most-first; when one closes, the next opener starts a new region —
the same rule most language parsers follow.

### Embedding another language

`ref` another filetype's shared highlighter inside a region (Markdown code fences,
shell inside kakrc):

```
add-highlighter shared/kakrc/shell1 region -recurse '\{' '%?%sh\{' '\}' ref sh
```

Markdown loads languages dynamically: `require-module <lang>` then add a
`… ref <lang>` region keyed on the fence's language word, lazily on `NormalIdle`.

## General highlighters

| Type                                                        | Use                                                                       |
|-------------------------------------------------------------|---------------------------------------------------------------------------|
| `regex <re> <cap>:<face> …`                                 | color regex captures. `0` = whole match, `1`..`n` = groups, or named groups. `regex //\h*(TODO:)\N* 0:cyan 1:yellow,red` |
| `dynregex <expr> <cap>:<face>`                              | like `regex` but expands `<expr>` first; `dynregex '%reg{/}' 0:+i` highlights live search matches |
| `fill <face>`                                               | flood a region with one face (the usual region body for strings/comments) |
| `group [-passes colorize\|move\|wrap]`                      | container for other highlighters                                          |
| `line <n> <face>` / `column <n> <face>`                     | highlight a line/column                                                   |
| `flag-lines <face> <line-specs-opt>`                        | gutter flags from a `line-specs` option (lint, git)                       |
| `ranges <range-specs-opt>`                                  | apply faces to ranges from a `range-specs` option (diagnostics)           |
| `replace-ranges <range-specs-opt>`                          | display markup in place of ranges                                         |
| `show-matching`, `show-whitespaces`, `number-lines`, `wrap` | convenience highlighters with their own switches                          |

Note: the `|` characters in the `group` row are escaped (`\|`) so they aren't parsed as column breaks.

## Building keyword highlighters from the shell

Long keyword lists become alternations via the `join` helper (defined and explained
in `shell-and-portability.md`), and the same list feeds `static_words` completion —
the universal filetype idiom for declaring the grammar in one place:

```
evaluate-commands %sh{
    keywords='if else fn let return'
    types='int bool str'
    join() { sep=$2; eval set -- $1; IFS="$sep"; echo "$*"; }   # see shell-and-portability.md
    printf %s\\n "declare-option str-list mylang_static_words $(join "${keywords} ${types}" ' ')"
    printf %s "
        add-highlighter shared/mylang/code/keywords regex \b($(join "${keywords}" '|'))\b 0:keyword
        add-highlighter shared/mylang/code/types    regex \b($(join "${types}" '|'))\b 0:type
    "
}
```

## Faces

```
set-face <scope> <name> <facespec>
unset-face <scope> <name>
```

Facespec format: `[fg][,bg[,underline]][+attrs][@base]`.

- Colors: named (`red`, `bright-blue`, …), `default`, or `rgb:RRGGBB` / `rgba:RRGGBBAA`.
- Attributes (each letter): `u` underline, `c` curly, `U` double, `r` reverse,
  `b` bold, `i` italic, `s` strikethrough, `d` dim, `B` blink; finals `F`/`f`/`g`/`a`
  override instead of merge.
- `@base` applies the face on top of another (`+r@meta`).

Use **semantic built-in faces** in highlighters (`keyword`, `type`, `value`,
`string`, `comment`, `meta`, `attribute`, `function`, `module`, `operator`,
`documentation`, …) rather than raw colors — colorschemes redefine these, so your
syntax file stays theme-independent. Define your own faces (e.g. `DiagnosticError`)
for plugin UI, and let users restyle them.

### Markup strings

In `-markup` contexts (`echo -markup`, `info -markup`, `modelinefmt`,
`replace-ranges`, completion menu text) `{FaceName}` switches the active face until
the next tag. Escape a literal `{` as `\{`; `{\}` turns off markup for the rest of
the line — use it before untrusted text:

```
echo -markup "{Information}name:{\} %val{bufname}"
```
