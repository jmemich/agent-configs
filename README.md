# agent-configs

A cross-tool collection of skills, rules, and configuration for AI coding agents
(Claude Code, Cursor, …). Intended to be used as a submodule of [`dotfiles`](https://github.com/jmemich/dotfiles),
where `bootstrap.sh` symlinks the relevant pieces into place so the same skills are
available on any machine and in any project.

## Layout

```
agent-configs/
├── skills/                 # agent-neutral skills — the shared source of truth
│   └── build/SKILL.md      # /build — orchestrated, airgapped build pipeline
├── claude/                 # Claude-specific config that ISN'T a portable skill (lazy)
├── cursor/                 # Cursor-specific config: .mdc rules, etc. (lazy)
└── README.md
```

A skill is the unit of reuse. Each lives at `skills/<name>/SKILL.md` and is written to be
agent-neutral: the body is plain markdown that any capable agent can follow. Tool-specific
config that *isn't* a portable skill (Claude `settings.json`/agents, Cursor `.mdc` rules)
goes under `claude/` or `cursor/`; those folders are created when there's something to put
in them.

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

Wired through [`dotfiles`](https://github.com/jmemich/dotfiles), where this repo is a
submodule at `agent-configs/`. Running `bootstrap.sh` symlinks the skills into place:

```sh
# Claude Code reads skills from ~/.claude/skills/<name>/SKILL.md — link the whole dir.
ln -sfn "$DOTFILES/agent-configs/skills" "$HOME/.claude/skills"

# Cursor reads commands from ~/.cursor/commands/<name>.md — one link per skill.
for skill in "$DOTFILES/agent-configs/skills"/*/; do
    name="$(basename "$skill")"
    ln -sfn "$skill/SKILL.md" "$HOME/.cursor/commands/$name.md"
done
```

Linking the whole `skills/` dir for Claude means new skills are picked up automatically;
Cursor needs one link per skill, so `bootstrap.sh` loops. `git worktree` (used by `/build`)
is built into git — nothing extra to install, though the Brewfile pins a current `git`
since macOS ships an older Apple Git.
