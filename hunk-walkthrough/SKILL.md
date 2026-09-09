---
name: hunk-walkthrough
description: >-
  Guided, story-order review of a changeset in the user's live Hunk diff-viewer
  session: files reordered to tell the story, an inline agent note at each stop,
  and the user stepping through with `{`/`}`. Use when the user asks to be
  walked through changes in Hunk (e.g. "walk me through these changes in hunk",
  "tour this diff in hunk").
---

# Hunk Walkthrough

Narrated review in the user's live Hunk TUI: files reordered into a story,
inline agent notes at each stop, and the user steps through with `{`/`}`
(previous/next annotated hunk).

The mechanism is Hunk's `--agent-context` JSON sidecar, loaded into the live
session via `hunk session reload`. The sidecar is what lets you set the file
order; live `comment add` notes alone can't do that. Hunk's bundled skill
covers everything else about driving a live session, so this skill adds only
what the sidecar workflow needs.

## Prerequisites

1. Run `hunk skill path` and Read the `SKILL.md` it points to. It is the
   authoritative reference for every `hunk session *` command used below and
   tracks the installed Hunk version, so always read it live.
   - If the command isn't found, Hunk isn't installed: point the user at
     https://hunk.dev/docs/start/install/ and stop.
2. Run `hunk session list`. If no session is live, ask the user to open one
   (`hunk diff` or `hunk show <ref>`) in their own terminal and wait for it.

## Further docs

The bundled skill from step 1 covers the `hunk session *` CLI. For anything
beyond it, fetch the specific doc page as Markdown: take the page URL and
replace its trailing `/` with `.md`. Pages relevant to this skill:

- https://www.hunk.dev/docs/agents/agent-context-and-stml.md — sidecar format
- https://www.hunk.dev/docs/agents/live-session-control.md — targeting, navigate, reload
- https://www.hunk.dev/docs/agents/comments-and-annotations.md — comments and highlights
- https://www.hunk.dev/docs/start/keyboard-and-mouse.md — the keys the user presses
- https://www.hunk.dev/docs/help/troubleshooting.md
- https://www.hunk.dev/docs/reference/cli.md — every flag; the site documents the
  latest release, so prefer `hunk <command> --help` for the installed version

Skip the corpus files. https://hunk.dev/llms-small.txt has the same text but
collapses headings and tables into single run-on lines, and
https://hunk.dev/llms-full.txt is ~70k tokens, mostly changelog and
extension-API docs. The Markdown index at https://www.hunk.dev/docs.md links
only a subset of pages; the full page list is only in the HTML site nav.

## Build the walkthrough

1. Inspect the changeset (`hunk session review --repo . --json` plus normal
   git/file reads) and pick a **story order** — the sequence that best
   explains the change, not file order. Typically: the core change first,
   then what depends on it, then tests and plumbing.
2. Write an agent-context sidecar JSON. Hunk's canonical example is
   `examples/3-agent-review-demo/agent-context.json` in its GitHub repo
   (modem-dev/hunk); the subset this workflow uses:

   ```json
   {
     "version": 1,
     "summary": "One-line framing of the whole changeset.",
     "files": [
       {
         "path": "src/foo.cljs",
         "summary": "Stop 1 — why this file leads the story.",
         "annotations": [
           {
             "newRange": [10, 14],
             "summary": "What the reviewer is looking at.",
             "rationale": "Why it's safe / what they wouldn't spot alone.",
             "author": "claude"
           }
         ]
       }
     ]
   }
   ```

   - `files` array order = review stream order = `{`/`}` traversal order.
   - Annotations target `newRange` (working version) or `oldRange` (the file
     at HEAD — use for deletions), both 1-based `[start, end]`. Verify line
     anchors with grep against the actual file; don't guess.
   - The bundled skill's guidance on what deserves a comment applies to
     annotations too.

   **Where to put it.** Reload refuses a path outside the session's initial
   Hunk root, and the file should stay out of the diff, since `hunk diff`
   shows untracked files by default:
   - Normal checkout: `.git/hunk-walkthrough.json`.
   - Linked worktree: `.git` is a file there, not a directory. Write the
     sidecar at the worktree root instead and exclude it via
     `git rev-parse --git-path info/exclude` (append the filename to that
     file, once).
3. Load it with `hunk session reload`, repeating the session's original review
   command (`hunk session get --repo .` shows it as `Source`) so the loaded
   content doesn't change under the user:

   ```
   hunk session reload --repo . -- diff --agent-context .git/hunk-walkthrough.json
   ```

   For a `show` session: `-- show <ref> --agent-context <path>`. Confirm it
   landed with `hunk session review --repo . --include-notes --json`.
4. Reload preserves prior live agent comments. If any duplicate the sidecar
   notes, run `hunk session comment clear --repo . --yes` (user comments are
   spared by default) and reload again.
5. Navigate to stop 1, then give the user the stop list — one line per file,
   in order, saying what each stop shows — and remind them to walk with
   `{`/`}`.

## Afterwards

- Collect the user's inline replies:
  `hunk session comment list --repo . --type user --json`.
- To extend the tour, edit the sidecar and reload with the same command. For
  one-off additions mid-tour, the bundled skill's live comments and highlights
  coexist with sidecar notes.
