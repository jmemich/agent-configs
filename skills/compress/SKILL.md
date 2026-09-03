---
name: compress
description: Prune bloated prose (docs and comments) down to a codebase's mutually intelligible surface. A read-only cartographer sub-agent reads the CODE ALONE and regenerates the minimal doc-surface the code implies; the orchestrator diffs that against existing prose, classifies every unit as redundant / orthogonal / stale / missing, and applies the safe prunes on a new branch as a reviewable diff. Code is the source of truth and is never modified. Single pass — you gate what to keep by reviewing the branch. Use only when the user explicitly invokes /compress with a path or prompt — never auto-invoke from ambient context.
disable-model-invocation: true
---

# /compress — regenerate the surface, prune to it

You are the **orchestrator**. A `/compress` run takes a target subtree and shrinks its
prose — Markdown docs and code comments — down to what a human actually needs to hold,
using the code itself as the source of truth. You run **one pass** on a **new branch**,
then hand the decision back to the user.

The governing idea (also in `AGENTS.md`): **the on-disk artifact is a cache of human
understanding, and code is the source of truth behind it.** Prose that merely restates the
code is regenerable and not worth caching; prose earns its place only by holding what code
can't — the *why*, external constraints, and synthesis a reader can't cheaply reconstruct.

This file is self-contained: the protocol, the sub-agent spec, and the artifact templates
are all below. Follow it exactly.

## Usage

- `/compress <path>` — compress prose under a subtree (its docs + the comments in its code).
- `/compress <prompt>` — compress the area the prompt names.
- `/compress` with no argument — infer the target from the conversation; if unclear, ask one question.

## The cardinal rule: propose on a branch, never silently delete

As orchestrator you **never**:
- change code semantics — this pass edits **prose only** (Markdown, and comment lines; never
  the statements around them),
- delete prose on the user's working branch or on main,
- edit files inside a git submodule (flag them instead),
- auto-merge or auto-iterate.

You **may**: explore the repo read-only, dispatch the cartographer, write files under
`.compress-skill/`, cut a branch, apply the safe prunes there as a diff, and talk to the
user. If a prune isn't clearly safe, you **flag** it rather than apply it.

## The regeneration diff (why it works)

The cartographer reads the **code alone** and emits the *minimal* surface the code implies
— deliberately blind to existing prose so it can't inherit its bloat. You then diff that
derived surface against the prose that exists and sort every unit into four buckets:

| Bucket | Test | Action |
| --- | --- | --- |
| **Redundant** | derivable from code *and* already present in prose | **prune** — unless it's a synthesis expensive for a *human* to reconstruct (an architecture map, a subsystem contract); those stay |
| **Orthogonal** | present, not derivable from code, doesn't contradict it (a genuine *why* / external constraint) | **keep** — move any path-not-taken narrative to the commit body |
| **Stale** | present, but **contradicts** the code | **cut** |
| **Missing** | derivable + human-expensive, but absent from prose | **flag** only — do not auto-write it this pass |

Two rules that keep the diff honest:
- **"Derivable from code" ≠ "delete."** The axis is *cost to a human to regenerate*, not mere
  presence in the code. Keep the syntheses that make the surface intelligible.
- **Stale = contradiction, not age.** Code can neither confirm nor deny a *why* (it's about
  the outside world) → orthogonal → keep. Code *can* contradict a wrong claim → stale → cut.

## Scratch layout

All run state lives in `.compress-skill/` in the **target repo** (never this skill's repo):

```
.compress-skill/
  derived-surface.md   # cartographer output: the minimal surface the code implies
  findings.md          # your classification of every prose unit (the four buckets)
  status.md            # your pass log
  agents/
    cartographer/ spec.md  report.md
```

## Protocol (single pass)

**0. Resolve target & scope.** Determine the subtree from the argument or conversation. Keep
it small — a package, a module, a `docs/` area. Regenerating a whole large repo's surface is
expensive and rarely needed; scope to the part being compressed.

**1. Prepare the workspace.** Ensure `.compress-skill/` is git-ignored: if the target repo's
tracked `.gitignore` doesn't list it, append (do not commit):
```
# /compress skill scratch (safe to delete)
.compress-skill/
```
Then, per repo hygiene, **cut a new branch** for the rewrite (e.g. `compress/<area>`).
Before branching, **ask what to do with any uncommitted or untracked work** on the current
branch so it's preserved. Create the `.compress-skill/` tree above.

**2. Dispatch the cartographer (read-only).** Write `agents/cartographer/spec.md` from the
template and dispatch one **read-only** sub-agent scoped to the target's **code**. It reads
the code — treating any comments it sees as claims to verify, not as ground truth — and
writes `derived-surface.md`: the minimal doc-surface the code implies, plus a short list of
spots where behavior is genuinely non-obvious from code alone (the legitimate homes for
*why*). It must itself obey the happy-path / no-restatement stance, or you'll diff bloat
against bloat.
- *Claude Code*: one Agent tool call with `readonly: true`.
- *Cursor*: one read-only sub-agent (Ask mode).

**3. Classify.** Read `derived-surface.md` and the existing prose in scope (docs + the
comments in the code). Write `findings.md`: for every prose unit, its bucket and a
one-line rationale. This is the artifact you and the user reason over.

**4. Apply the safe prunes on the branch.** Turn `findings.md` into edits:
- **Redundant** → delete (unless flagged human-expensive synthesis → keep).
- **Stale** → delete.
- **Orthogonal** → keep in place; if it carries path-not-taken narrative, lift that into the
  commit body (step 5) and leave only the load-bearing *why*.
- **Missing** → do **not** write; record under "Flagged for you".
- If a doc outgrew its purpose, split it and link the pieces from an index rather than
  leaving one sprawling file.
Edit comment lines conservatively: remove or shorten the comment text only — never touch the
code statements. Commit the result **on the branch** so the diff is reviewable.

**5. Preserve discovery in the commit.** Write the compression commit with the salvaged
path-not-taken / "why we changed it" narrative in the **body**, co-located with the work.
Git log becomes the cold store; the prose stays lean. Leave a pointer in prose only if a
future reader would otherwise never find it.

**6. Surface the result.** Update `status.md` and report to the user:
- the **branch name** and a `git diff --stat` of what changed,
- a short **findings summary**: what was cut and why, what was kept, how much prose shrank,
- the **"Flagged for you"** list: missing syntheses worth writing, and any prune you judged
  too risky to apply.

Do not merge and do not touch main. The user reviews the branch and decides what to keep.

---

## Templates

### `agents/cartographer/spec.md`

```markdown
# Cartographer spec (read-only)

You are the **cartographer**. Read the CODE in the scope below and regenerate the *minimal*
documentation surface it implies. You are deliberately blind to the existing docs: derive
the surface from the code so it can't inherit the docs' bloat.

## Scope
<paths to read — the target subtree's source>

## Rules
- Read ONLY the code in scope. Do not read `docs/` or treat comments as authoritative —
  a comment is a claim to verify against the code, not ground truth.
- Emit the surface a human needs to hold, nothing more: purpose, public interface,
  cross-cutting behavior, and the invariants that aren't obvious from a single file.
- Obey the happy-path / no-restatement stance: do not enumerate every branch, do not narrate
  line-by-line, do not restate what a signature already says.
- Separately, list the few spots where behavior is genuinely non-obvious from the code alone
  — these are the legitimate homes for a *why* comment or doc.

## When done
Write `.compress-skill/agents/cartographer/report.md` = the derived surface (as the doc-set
the code implies) + the "non-obvious spots" list. Also copy the derived surface to
`.compress-skill/derived-surface.md`.
```

### `findings.md`

```markdown
# Compression findings: <area>

Prose shrank from <N> → <M> lines across <k> files (fill in after step 4).

## Redundant → pruned
- `path#anchor` — restates <what the code says>. (kept: none / <synthesis> because human-expensive)

## Stale → cut
- `path#anchor` — contradicts code: <the mismatch>.

## Orthogonal → kept
- `path#anchor` — non-derivable <why / constraint>. (discovery narrative → commit body)

## Missing → flagged for you (not written)
- <synthesis the code implies but no doc holds, and why it's worth a human writing>
```

### `status.md`

```markdown
# Compress status

- Target: <area>
- Branch: compress/<area>
- Pass: <n>

## This pass
- Cartographer: dispatched → derived-surface.md written
- Classified: <r> redundant, <s> stale, <o> orthogonal, <m> missing
- Applied on branch: <files touched>, prose <N> → <M> lines
- Discovery preserved in commit: yes/no

## Flagged for you
- <missing synthesis / prune judged too risky to apply>   (or "none")
```

---

## Principles

- **Code is the source of truth; prose is a cache.** Regenerate the surface from code, then
  prune prose down to it.
- **Regenerate blind.** The cartographer must not read the docs, or it inherits their bloat.
- **Cut on contradiction, keep on orthogonality.** That line separates rot from irreplaceable *why*.
- **Lossy where recoverable.** Prose is regenerable from code, so prune it freely; code is
  load-bearing and is never touched this pass.
- **Propose on a branch; the user gates.** One pass, a reviewable diff, discovery saved in the
  commit — you decide what to merge.
