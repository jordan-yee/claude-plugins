# Regex dialect

Kakoune's regex is ECMAScript-flavored but with important additions and a few
divergences. It is used in hook filters, highlighter patterns, `<a-k>`/`s`/`<a-s>`
key conditions, and `regex`/`range-specs` options. Reference: `:doc regex`
(interactive; read the same content on disk at
`<prefix>/share/kak/doc/regex.asciidoc` — see SKILL.md for the prefix). Matching is
always over **Unicode
codepoints**, never bytes.

## Cheat sheet

- Literals: every char except `\^$.*+?[]{}|().` matches itself; escape syntax chars
  with `\`.
- Escapes: `\n \r \t \f \v \0`, `\cX` (control), `\xXX`, `\uXXXXXX` (6 hex digits —
  not surrogate pairs).
- Classes: `\d \w \s` and negations `\D \W \S`. `[...]`, `[^...]` custom classes.
- Quantifiers: `? * + {n} {n,} {n,m} {,m}`; suffix `?` for non-greedy.
- Groups: `(...)` capturing, `(?:...)` non-capturing, `(?<name>...)` named.
- Alternation: `a|b` (prefers the left).
- Anchors/assertions: `^ $` (line start/end), `\b \B` (word boundary), `\A \z`
  (subject start/end). Lookarounds `(?=) (?!) (?<=) (?<!)`.
- Modifiers: `(?i)`/`(?I)` case-insensitive/sensitive, `(?s)`/`(?S)` dot matches /
  doesn't match newline.

## Kakoune-specific additions (use these — they matter)

- **`\h`** — horizontal blank (space/tab), not vertical tab or line breaks. This is
  the idiom for "indentation/leading whitespace": `^\h+`, `\h*$`. Prefer `\h` over
  `\s` whenever you mean spaces-and-tabs-on-a-line.
- **`\N`** — any character **except** newline, unaffected by `(?s)/(?S)`. Note `.`
  matches newlines **by default** in Kakoune, so use `\N` when you want "rest of
  line": `//\N*` (a line comment), `(?://\N+)?` (optional trailing comment).
- **`\K`** — reset the start of capture 0 to the current position; everything before
  `\K` is matched but excluded from the selection. Used constantly to match a prefix
  without selecting it: `(^|\h)\K#` (a `#` not at the start of a word),
  `^\h*\K#\h*(?:define|if)`.
- **`\Q…\E`** — quote a literal run. Essential when interpolating user/option text
  into a pattern so its metacharacters don't apply: `\A\Q%opt{comment_block_begin}\E`.

## Divergences from ECMAScript

- `.` matches newline by default (toggle with `(?s)`/`(?S)`); `\N` is the
  newline-excluding "any char".
- Lookbehind **is** supported, but lookaround bodies must be a fixed sequence of
  literals/classes/`.` — **no quantifiers inside lookarounds** (performance).
- Stricter escaping: identity escapes like `\X` for a non-special `X` are rejected
  (avoids the `\h`-means-literal-h confusion). Only the defined escapes are valid.

## Patterns you'll reuse

- Leading indentation: `^\h+` ; blank-but-whitespace line: `^\h+$` ; trailing
  whitespace: `\h+$`.
- Line ends with an opener: `[{(]\h*$` (with optional comment: `[{(]\h*(?://\N+)?$`).
- Whole-param hook filters must match entirely: `filetype=(c|cpp|objc)`,
  `pop:insert:.*`.
- Capture into registers via a selection regex, then read `%reg{1}`…:
  `s^([^:\n]+):(\d+):(\d+)?<ret>` → filename/line/column in registers `1`/`2`/`3`.
- Match-but-don't-select a prefix: `prefix\Ktarget`.
- Anchor a `set-register /` search to the start: `set-register / "\A%opt{pat}"`.

## In highlighters

`add-highlighter … regex <re> <cap>:<face> …` colors capture groups: `0` whole
match, `1..n` numbered groups, or named-group names. Keep patterns anchored and use
`\b`, `(?<!…)`, lookarounds to avoid over-matching across tokens (see the numeric
literal patterns in `c-family.kak` for thorough examples).
