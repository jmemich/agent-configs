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
│   └── build/SKILL.md      # /build — orchestrated, airgapped build pipeline
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

## Deployment

This repo owns its own deployment. Run `./setup.sh` to create:

- `~/.claude/CLAUDE.md` → `CLAUDE.md` (the shim)
- `~/.claude/AGENTS.md` → `AGENTS.md`
- `~/.claude/skills` → `skills/` (whole dir; new skills picked up automatically)
- `~/.cursor/commands/<name>.md` → `skills/<name>/SKILL.md` (one link per skill)

The script is idempotent and self-locating. Run it here directly, or let
[`dotfiles/setup.sh`](https://github.com/jmemich/dotfiles) invoke it (this repo is
wired as a submodule at `agent-configs/` in dotfiles).

**Cursor User Rules note.** Cursor has no global `AGENTS.md` file location — its
global rules live in *Settings → Rules*. To apply these rules in Cursor globally,
paste `AGENTS.md`'s contents into that UI once per machine; re-paste after edits.
Per-project use of `AGENTS.md` in a repo's root is read by Cursor normally.
