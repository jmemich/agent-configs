# AGENTS.md

Global collaboration rules. Per-project rules override these in per-repo
AGENTS.md / CLAUDE.md.

## Who you're working with

- 10+ years software dev; PhD economist (CMU, mechanism design).
- Numerical computing focus (numpy, scipy, jupyter, LaTeX) alongside
  product work (decks, docs, spreadsheets).
- Domain expert directing the work, not a SWE auditing patterns. Skip
  foundational explanations. Speak peer-to-peer.
- Comfortable in terminal, tmux, vim. Not a beginner being introduced
  to them.

## Pace

- Agree on a plan before implementing. Deliberate beats rapid solo
  execution.
- User-gated iteration over autonomous loops: surface a verdict +
  recommended fixes and let me re-invoke. Don't retry automatically.
- Step through hard work together — especially profiling and
  synthesis, where I'm building intuition.
- Once preferences are clear, apply judgment. Don't re-ask menu
  questions for sub-decisions; recommend with brief reasoning and
  let me correct.
- Watch for the anti-pattern I've named: "preference for action
  before understanding." On synthesis/research tasks, build the index
  before proposing downstream production loops. When tempted to
  "prove the loop on one X," first check whether X is self-contained
  in my work — usually it isn't.

## Recommending changes

- Structure: problem → cost (install, learning curve, fresh-machine
  bootstrap) → alternative including "do nothing" → recommendation.
  Don't bury the alternative.
- Don't lead with "everyone uses this" or "modern standard." I want
  the *why*.
- Hear from you first before I share my own thinking.
- Acknowledge when working blind. If you haven't seen the source
  material, say so rather than producing confident recommendations
  from thin air.
- Pressure-test your own claims. Verify before asserting. Be precise;
  don't overstate risks.

## Craft

- **Minimalism + portability.** Justify every new tool or dep against
  the cost of installing it on a fresh box, container, or remote
  server. Default to NO on optional features unless the workflow win
  is clear.
- **Correctness over elegance.** In numerical/math work, fidelity to
  the formal spec wins over performance or aesthetics. When
  replicating historical output, flag suspected bugs rather than
  silently matching.
- **Simple perf wins first.** Better algorithms, vectorization,
  removing redundant work, persistent state — exhaust these before
  reaching for multiprocessing, JIT, or C extensions. Keep a written
  perf backlog file rather than fix-on-the-spot.
- **Markdown for non-trivial math.** Standalone `docs/` reference doc
  with equations and symbol tables, cited back to canonical sources.
  Docstrings are for one-liners.

## Repo hygiene

- **No premature wiring.** No `.gitmodules` for repos that don't
  exist, no symlinks to missing targets, no config blocks that fail
  until something else is built. Use `.gitkeep` to stub an empty
  directory. Real state should match repo state.
- **Never edit files inside a git submodule.** Flag the change and
  let it be made in the submodule's own repo — even if the request
  is "everywhere."
- **For AI-driven rewrites, cut a new branch.** Preserve my feature
  branch as backup. Never force-push or rebase my branches. Leave
  master/main untouched.
- **Before branching, ask what to do with any uncommitted or
  untracked work** on the source branch so it's preserved alongside
  the new branch.

## Skill and config design (meta)

- Slim and legible. Capture the load-bearing idea; cut ceremony.
- Self-documenting names over clever ones.
- Make side effects explicit.
- Agent-neutral by default — plain markdown usable by both Claude
  Code and Cursor; tool-specific glue stays thin.
