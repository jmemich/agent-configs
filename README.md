# agent-configs

A cross-tool collection of skills, rules, and configuration for AI coding agents
(Claude Code, Cursor, …). Intended to be used as a submodule of [`dotfiles`](https://github.com/jmemich/dotfiles),
where `setup.sh` symlinks the relevant pieces into place so the same skills are
available on any machine and in any project.

## Layout

```
agent-configs/
├── AGENTS.md               # global collaboration rules — source of truth, tool-neutral
├── CLAUDE.md               # one-line `@./AGENTS.md` shim for Claude Code's loader
├── setup.sh                # idempotent: symlinks rules + skills into ~/.claude and ~/.cursor
├── skills/                 # agent-neutral skills
│   ├── build/SKILL.md          # /build — orchestrated, airgapped build pipeline
│   ├── compress/SKILL.md       # /compress — prune prose to the code's intelligible surface
│   └── ds-validation/SKILL.md  # /ds-validation — author a scientist's audit notebook
└── README.md
```

`AGENTS.md` is the canonical source of truth — tool-neutral, cross-agent. `CLAUDE.md`
is a one-line shim that imports it, so Claude Code's `~/.claude/CLAUDE.md` loader picks
up the same content regardless of how AGENTS.md support shifts in any single tool.

A skill is the unit of reuse. Each lives at `skills/<name>/SKILL.md` and is written to be
agent-neutral: the body is plain markdown that any capable agent can follow.

## Skills

### `/build`

An orchestrated, **airgapped** build pipeline distilled from the
[statsclaw](https://github.com/statsclaw/statsclaw) framework. The agent running `/build`
acts as an **orchestrator**: it authors an interface **contract** from your request, then
dispatches three isolated sub-agents —

- **builder** — writes code from a sliced spec (never sees the tests),
- **tester** — writes tests against the contract (never sees the implementation),
- **validator** — the adversarial convergence point: runs the tests in the merged tree and
  judges the result against your original request.

Builder and tester are isolated in their own git worktrees so neither can "teach to the
test". `/build` runs a **single pass** and reports a verdict plus recommended fixes — *you*
decide what to change and re-invoke. Run state lives in `.build-skill/` in the target repo
(git-ignored). See [`skills/build/SKILL.md`](skills/build/SKILL.md) for the full protocol.

### `/compress`

Prunes bloated prose — Markdown docs and code comments — back to a codebase's *mutually
intelligible surface*, on the principle (see `AGENTS.md`) that **code is the source of
truth and prose is a cache of what code can't say.** A read-only **cartographer** sub-agent
reads the *code alone* and regenerates the minimal doc-surface it implies — blind to the
existing docs so it can't inherit their bloat. The orchestrator then diffs that against the
prose that exists and classifies every unit:

- **redundant** (restates the code) → prune, unless it's a synthesis expensive for a *human* to reconstruct,
- **orthogonal** (a genuine *why* the code can't confirm) → keep,
- **stale** (contradicts the code) → cut,
- **missing** (implied by code, absent from docs) → flag, don't auto-write.

Code semantics are never modified. Changes land on a `compress/<area>` branch as a
reviewable diff, salvaged "why we did it" narrative goes into the commit body (git as the
cold store), and it runs a **single pass** — *you* review the branch and decide what to
keep. See [`skills/compress/SKILL.md`](skills/compress/SKILL.md).

### `/ds-validation`

Authors a validation for a piece of data-science work — a fitted model, a data-prep
output, a summary table — as up to **two co-located artifacts under
`outputs/ds-validation/<slug>/`**: a `<slug>_run.py` that does the heavy computation
once and dumps its results to disk (with minimal progress prints), and a
`<slug>_validation.ipynb` that loads those results and renders only the diagnostics the
operator asked for. The split exists so the notebook always reruns promptly — iterating
on it never re-fits a model or re-processes a table. **The run script is optional**:
if the intermediates the notebook needs are already on disk from a prior run, the agent
skips writing it and points the notebook at the existing files.

Three load-bearing rules the agent must follow: **assume the happy path** (no defensive
guards, no `try/except`, no schema asserts, no `assert`s at all unless the operator
explicitly asks for one as a check — a broken pipeline shows up as a traceback, which
is the right signal); **minimum dependencies** (if pandas works, don't reach for Spark;
every added import is one more thing the reviewer's box has to have installed); **ask
before guessing** (unclear targets, unclear checks, unclear inputs, and unclear
intermediate locations each get one focused question — never plausible-looking defaults
or bonus diagnostics).

Flow: the agent verifies prereqs (`jupyter`, every package both artifacts will import,
project modules the run script calls), checks disk for existing intermediates, writes
the run script only if needed, **executes it** and streams its progress prints, then
writes the notebook and hands you the launch command on completion. Single pass; you
edit the notebook or re-invoke `/ds-validation` with a delta to change checks. See
[`skills/ds-validation/SKILL.md`](skills/ds-validation/SKILL.md).

## Deployment

This repo owns its own deployment. Run `./setup.sh` to create:

- `~/AGENTS.md` → `AGENTS.md` and `~/CLAUDE.md` → `CLAUDE.md` (home-root, for agents that read `$HOME` directly)
- `~/.claude/CLAUDE.md` → `CLAUDE.md` (the shim)
- `~/.claude/AGENTS.md` → `AGENTS.md`
- `~/.claude/skills` → `skills/` (whole dir; new skills picked up automatically)
- `~/.cursor/skills` → `skills/` (whole tree; same layout as Claude)

The script is idempotent and self-locating. Run it here directly, or let
[`dotfiles/setup.sh`](https://github.com/jmemich/dotfiles) invoke it (this repo is
wired as a submodule at `agent-configs/` in dotfiles).

**Cursor User Rules note.** Cursor has no global `AGENTS.md` file location — its
global rules live in *Settings → Rules*. To apply these rules in Cursor globally,
paste `AGENTS.md`'s contents into that UI once per machine; re-paste after edits.
Per-project use of `AGENTS.md` in a repo's root is read by Cursor normally.
