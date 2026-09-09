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
order; live `comment add` notes alone can't do that.

## Prerequisites (check in order)

1. Run `hunk skill path` and Read the `SKILL.md` it points to. It is the
   official CLI reference for live sessions and tracks the installed Hunk
   version, so always read it live; it is authoritative for every
   `hunk session *` command used below.
   - If the command isn't found, Hunk isn't installed: point the user at
     https://hunk.dev/docs/start/install/ and stop.
2. Run `hunk session list`. If no session is live, ask the user to launch
   `hunk diff` (or `hunk show <ref>`) in their own terminal — it's an
   interactive TUI, so never run it yourself — then continue once the
   session appears.
3. Run `hunk session get --repo .` and note the `Source`. The reload in step 3
   below must repeat the same review command (`diff`, `diff <ref>`,
   `show <ref>`, pathspecs) so the loaded content doesn't change under the
   user.

Further docs when needed: https://hunk.dev/llms.txt is an index of docs for
reference by llms, which links to MD files with complete doc sets, which may
be useful to reference for ensuring all documentation is understood, but will
likely not be the most token efficient approach for specific questions.

The official doc site is at https://www.hunk.dev/docs/. Append `.md` to any
page URL for its Markdown source (e.g. https://www.hunk.dev/docs/agents/review-with-an-agent/ -> https://www.hunk.dev/docs/agents/review-with-an-agent.md;
). Note that these pages have a trailing `/` that you'd replace with the `.md`
suffix to read as MD. This returns the page content as an MD file without the
nav menu on the left side of the page when rendered in-full. The most efficient
strategy is likely to load the [overview page](https://www.hunk.dev/docs/)
normally to get an index of the available doc pages, then fetch a target page
identified from that directly as MD.

## Build the walkthrough

1. Inspect the changeset with `hunk session review --repo . --json` (add
   `--include-patch` only for files you need in raw diff form) plus normal
   git/file reads. Pick a **story order** — the sequence that best explains
   the change, not file order. Typically: the core change first, then what
   depends on it, then tests and plumbing.
2. Write an agent-context sidecar JSON. Minimal shape:

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
   - Not every hunk needs a note. Annotate what the reviewer wouldn't spot
     alone: intent, non-obvious structure, risks, follow-ups. One note per
     stop is often enough.

   **Where to put it.** The path must be inside the session's initial Hunk
   root — anything outside is refused. It should also stay out of the diff,
   since `hunk diff` shows untracked files by default:
   - Normal checkout: `.git/hunk-walkthrough.json`. `.git/` is inside the root
     and never appears in the working-tree diff.
   - Linked worktree: `.git` is a file there, not a directory. Write the
     sidecar at the worktree root instead and exclude it via
     `git rev-parse --git-path info/exclude` (append the filename to that
     file, once).
3. Load it, mirroring the session's original review command:

   ```
   hunk session reload --repo . -- diff --agent-context .git/hunk-walkthrough.json
   ```

   For a `show` session: `-- show <ref> --agent-context <path>`. Then confirm
   it landed with `hunk session review --repo . --include-notes --json` — the
   file order and annotations should match the sidecar.
4. Reload preserves prior live agent comments. If any duplicate the sidecar
   notes, run `hunk session comment clear --repo . --yes` (user comments are
   spared by default) and reload again.
5. Navigate to stop 1 (`hunk session navigate --repo . --file <path>
   --new-line <n>`, or `--next-comment`), then give the user the stop list —
   one line per file, in order, saying what each stop shows — and remind them
   to walk with `{`/`}`.

## Afterwards

- Collect the user's inline replies:
  `hunk session comment list --repo . --type user --json`.
- To extend the tour (new increments, follow-ups), edit the sidecar and
  reload with the same command; one-off notes can instead be live comments
  (`comment add` / `comment apply`) — they coexist with sidecar notes.
- Live tools still apply mid-tour: `highlight add --focus` lights up the exact
  expression you're explaining; `highlight clear` before moving on.

## Common errors

- **"Session reload refused agent context path outside the initial Hunk
  root"** — the sidecar isn't under the root the session was launched from.
  Move it (see *Where to put it* above).
- **"No active Hunk sessions"** while Hunk is visibly running — the sandbox
  is likely blocking loopback; retry with network access. Otherwise the user
  needs to open Hunk.
- **"No diff file matches ..."** — a sidecar `path` or `--file` value isn't in
  the loaded review. Paths must match what `hunk session review` reports.
