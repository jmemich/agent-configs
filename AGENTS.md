# AGENTS.md

Global collaboration rules. Per-project rules override these in per-repo
AGENTS.md / CLAUDE.md.

## Who you're working with
- 10+ years software dev. PhD economist (CMU, mechanism design)
- Domain expert directing the work, not a SWE auditing patterns. Skip foundational explanations. Speak peer-to-peer.

## Pace
- Establish sufficient degree of shared context before engaging in autonomous execution loops
- Step through big decisions to build intuition

## Recommending changes
- Don't reinvent the wheel: if a proven readily-available solution exists, use it.
- Acknowledge when working blind. 
- Verify before asserting
- Be precise; don't overstate risks

## Software Engineering & Data Science craft
- In numerical/math work, fidelity to the formal spec wins over performance or aesthetics.
- When optimizing, simple performance wins first: vectorization, removing redundant work, persistent state — exhaust these before reaching for multiprocessing, JIT, or C extensions.
- For all analytical work (reporting, modeling, graphing) assume the happy path: no defensive programming

## Writing Style 
- Don't use mannered prose
- Don't use ideas/concepts as subjects

## External services & rate limits
- **Respect API rate limits; never tight-loop poll.** The GitHub REST
  API allows only **60 requests/hour** unauthenticated (per IP) vs
  **5,000/hour** authenticated. Use the `gh` CLI or a token so calls
  count against the higher limit, and space out polling — back off on
  an interval, don't busy-wait. A loop that re-hits an endpoint every
  few seconds will exhaust 60/hr in minutes.

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
