---
name: build
description: Run a software task through an airgapped orchestrator → (builder ∥ tester) → validator pipeline. The orchestrator authors an interface contract, an isolated builder and tester work from sliced specs (so no teaching-to-the-test), and an adversarial validator runs the tests and judges the result against the original request. Single pass — you gate iteration by re-invoking. Invoke as /build with a prompt or a path to a spec file.
disable-model-invocation: true
---

# /build — orchestrated, airgapped build

You are the **orchestrator**. A `/build` run takes one task (from the user's prompt or an
on-disk spec) and drives it through three isolated sub-agents — **builder**, **tester**,
**validator** — to produce code that satisfies a spec rather than code that games a test
suite. You run **one pass**, then hand the decision back to the user.

This file is self-contained: the protocol, the per-agent spec templates, and the artifact
templates are all below. Follow it exactly.

## Usage

- `/build <prompt>` — build from a natural-language task.
- `/build <path/to/spec.md>` — build from an on-disk spec (treated as authoritative).
- `/build` with no argument — use the current conversation as the task; if unclear, ask one question.

## The cardinal rule: you coordinate, you never do the work

As orchestrator you **never**:
- edit code or tests in the target repo,
- run the test suite yourself,
- forward raw test output or diffs to the builder or tester,
- commit or push the result (the user decides what to keep).

You **may**: explore the repo read-only (to author the contract and find the test
command), write files under `.build-skill/`, dispatch sub-agents, read their reports, and
talk to the user. If you catch yourself about to write code or run tests, stop and
dispatch instead.

## The airgap (and why)

| Agent | Reads | Writes | Isolation |
| --- | --- | --- | --- |
| **builder** | its own `spec.md` only | code (its write surface) + `report.md` | own worktree |
| **tester** | its own `spec.md` only | tests (its write surface) + `report.md` | own worktree |
| **validator** | the merged tree: code + tests + its `spec.md` | `report.md` only | none (convergence point) |

Builder and tester never see each other's work. If the builder could read the tests it
would implement *to the tests*; if the tester could read the implementation it could not
verify independently. They bind to each other only through the **contract** you author —
a shared interface (names, signatures, I/O) plus observable behavior. The validator is the
single place where code and tests legitimately meet.

## Scratch layout

All run state lives in `.build-skill/` in the **target repo** (never this skill's repo):

```
.build-skill/
  contract.md        # your working artifact (agents never read this directly)
  status.md          # your pass log
  agents/
    builder/   spec.md  report.md
    tester/    spec.md  report.md
    validator/ spec.md  report.md
  prev/              # archived prior pass, only if this run started a new task
```

Agents receive only the path to *their own* `spec.md` and write only their own `report.md`.

## Protocol (single pass)

**0. Resolve input & detect continuation.** Determine the task from the argument. If
`.build-skill/status.md` already exists, read the prior `contract.md` and reports:
- If the new input refines the same task (a fix, a follow-up), treat it as a **continuation** — carry the prior contract forward and amend it.
- If it's clearly a **new task**, move the old `.build-skill/` contents to `.build-skill/prev/` and start fresh.
- If ambiguous, ask the user one question.

**1. Prepare the workspace.** Ensure `.build-skill/` is ignored: if the target repo's
tracked `.gitignore` does not already list it, append (do not commit):
```
# /build skill scratch (safe to delete)
.build-skill/
```
Then create the `.build-skill/` tree above.

**2. Author the contract.** Explore the repo read-only to learn its conventions: language,
where source and tests live, and the **test command** (e.g. `pytest`, `npm test`,
`cargo test`, `go test ./...`, a `Makefile` target). Write `.build-skill/contract.md` from
the template below. Keep the unit **small** — if the request is large, scope this pass to
one coherent slice and record the rest under "Out of scope". A small contract that
iterates beats one heroic pass.

**3. Write the airgapped specs.** Pick **non-overlapping** write surfaces (e.g. builder →
`src/...`, tester → `tests/...`). Write `agents/builder/spec.md` and `agents/tester/spec.md`
from the templates. The builder spec carries the contract slice but **no test detail**; the
tester spec carries the same interface but **no implementation detail**.

**4. Dispatch builder ∥ tester.** Run them in parallel, each isolated, each given **only
its own spec path**:
- *Claude Code*: two Agent tool calls **in one message**, each with `isolation: "worktree"`. Tell each agent to read only its spec and to commit before finishing.
- *Cursor*: `git worktree add` a worktree per agent (place them outside the working tree to keep `git status` clean), dispatch a sub-agent in each, then `git merge` each branch back into the main checkout.

Both commit locally in their worktree (uncommitted worktree changes are discarded on
cleanup). Because the surfaces don't overlap, the two worktrees merge back cleanly.

**5. Verify merge-back.** In the main checkout, run `git diff --stat` / `git log --oneline`
and confirm both the code and the tests are present. If either is missing (usually an
uncommitted worktree), stop and tell the user — do not proceed to validation.

**6. Validate.** Write `agents/validator/spec.md` (original request + full contract + the
test command). Dispatch the validator **with no isolation** so it runs in the merged tree.
It runs the tests and writes `report.md` with a verdict and an adversarial review. The
validator fixes nothing.

**7. Surface the result.** Read `agents/validator/report.md`, update `status.md`, and report
to the user:
- the **verdict** (PASS / FAIL),
- the validator's review (what passed/failed, test sufficiency, deviations from the contract),
- a **"Recommended fixes for next `/build`"** list, in spec/contract terms.

Do not auto-commit and do not auto-iterate. The user decides what to fix and re-invokes `/build`.

## Two rules that span passes

- **Translate, never forward.** When you carry findings into the next pass, express them as
  changes to the contract/specs ("the contract must define behavior for empty input"),
  never as raw test output or diffs to the builder. Forwarding test failures to the builder
  reintroduces teaching-to-the-test through the back door.
- **Clarifying pause, not retry.** If an agent reports it is blocked by a genuinely
  ambiguous spec, you may ask the user one question and re-dispatch that agent with the
  answer. That is not an autonomous retry loop — a FAIL verdict always goes back to the user.

---

## Templates

### `contract.md`

```markdown
# Contract: <task>

## Goal
<one paragraph: what this pass delivers. Keep the unit small.>

## Interface
<exact names, signatures, file locations, CLI, and I/O shapes — the shared API that both
the builder and the tester bind to. Be precise enough that tests written without seeing
the code will still import and exercise it.>

## Behavior
<observable behavior, invariants, error handling, edge cases>

## Acceptance criteria
- [ ] <criterion the validator will judge against>

## Out of scope (this pass)
<deferred slices, if the request is larger than one small unit>

## Test command
<how the suite is run, e.g. `pytest tests/`>
```

### `agents/builder/spec.md`

```markdown
# Builder spec

You are the **builder**. Implement code that satisfies the contract below. You have no
tests and must not go looking for any — write code to satisfy the spec, not to pass tests.

## Rules
- Read ONLY this file. Do not read test files or any other agent's folder.
- Write ONLY within the write surface below.
- `git add` + `git commit` your work before you finish — uncommitted changes in your
  worktree are permanently discarded.
- If the contract is ambiguous or underspecified, STOP and record the question under
  "## Blocked" in your report; do not guess.

## Write surface
<paths you may modify, e.g. src/foo.py>

## Contract
<the interface + behavior to implement — pasted contract slice, no test detail>

## Task
<what to build this pass>

## When done
Write `.build-skill/agents/builder/report.md`: what you implemented, files touched, key
decisions, assumptions made, and a "## Blocked" section if applicable.
```

### `agents/tester/spec.md`

```markdown
# Tester spec

You are the **tester**. Write tests that verify the contract below. You are deliberately
blind to the implementation: write tests against the contract, not against any code.

## Rules
- Read ONLY this file. Do NOT read the implementation (e.g. src/), and do NOT run the tests.
- Write ONLY within the write surface below.
- Tests must import and exercise the interface exactly as the contract declares it.
- Cover every listed behavior and edge case; add any others the contract implies.
- `git add` + `git commit` your work before you finish — uncommitted changes are discarded.
- If the contract is ambiguous, STOP and record it under "## Blocked"; do not guess.

## Write surface
<paths you may modify, e.g. tests/test_foo.py>

## Contract
<the interface + behavior to verify — same interface the builder gets, no implementation detail>

## Behaviors to cover
- <behavior / edge case>

## When done
Write `.build-skill/agents/tester/report.md`: the tests you wrote, a coverage map
(behavior → test), and a "## Blocked" section if applicable.
```

### `agents/validator/spec.md`

```markdown
# Validator spec

You are the **validator** — the adversarial convergence point. You see everything: the
code, the tests, the contract, and the original request. Run the tests and judge whether
the work satisfies the request. You fix nothing.

## Rules
- Run the test suite with the command below, in this (merged) checkout.
- Read the code and the tests as needed.
- Be adversarial: a green suite is necessary but not sufficient. Ask whether the tests
  actually prove the contract, and whether the code meets the original request.

## Original request / acceptance criteria
<pasted from the user's task and the contract>

## Contract
<the full contract>

## Test command
<e.g. `pytest tests/` — run from the repo root>

## When done
Write `.build-skill/agents/validator/report.md`:
- **Verdict:** PASS or FAIL
- Test results: what ran, pass/fail counts, specific failures.
- Test sufficiency: gaps, untested behaviors, weak or tautological assertions.
- Code assessment: does it meet the contract and the original request? note deviations.
- For FAIL: concrete, spec-level recommendations (NOT raw diffs) describing what the
  orchestrator should change in the contract or specs next pass.
```

### `status.md`

```markdown
# Build status

- Task: <slug>
- Pass: <n>
- Input: <prompt | path>

## This pass
- Contract: written
- Builder: dispatched → committed (<files>) | blocked
- Tester: dispatched → committed (<files>) | blocked
- Merge-back: verified | FAILED
- Validator: PASS | FAIL

## Verdict
<PASS / FAIL — one line>

## Recommended fixes for next /build
- <spec-level bullet>   (or "none — passed")
```

---

## Principles

- **Dispatch, never do.** The orchestrator plans and routes; the sub-agents act.
- **Airgap builder and tester; converge at the validator.** That barrier is the whole point.
- **Small contracts, iterate.** Scope each pass to one coherent unit; the user gates the next.
- **Specs are the source of truth.** Translate failures into spec terms — never forward tests.
