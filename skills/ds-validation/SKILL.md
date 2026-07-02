---
name: ds-validation
description: Author a validation for a piece of data-science work as two co-located artifacts under outputs/ds-validation/<slug>/ — a <slug>_run.py that does the heavy computation once and dumps its results to disk, and a <slug>_validation.ipynb that loads those results and renders only the diagnostics the operator asked for. The split exists so the notebook always reruns promptly; iterating on the notebook never re-fits a model or re-processes a table. Before writing anything, check disk for the intermediates the notebook will consume — if they already exist (from a prior run or an operator-named path), skip the run script entirely. Assume the happy path: no defensive code, no try/except, no schema asserts. No assert statements unless the operator explicitly asks for one as a check. Use the minimum set of dependencies that satisfies the checks — do not reach for Spark if pandas works. Include only the diagnostics the operator asked for; if a check is ambiguous, ask before guessing. The agent verifies prereqs, writes the artifacts, executes the run script with basic progress logging, and hands the operator the notebook launch command on completion. Use only when the user explicitly invokes /ds-validation with a target and a checks list — never auto-invoke from ambient context.
---

# /ds-validation — a run script + an analysis notebook

Every `/ds-validation` run produces up to **two artifacts, co-located in
`outputs/ds-validation/<slug>/`**:

- `<slug>_run.py` — does the heavy computation the operator names (fit a model,
  process a table, materialise predictions) and writes intermediate results to the
  same folder, with minimal progress prints so both the agent and the operator can
  see how far in the run is.
- `<slug>_validation.ipynb` — loads those pre-computed results and renders **only**
  the diagnostics the operator asked for.

The split is the point. The run script runs once (slow). The notebook always reruns
fast because it does no heavy compute — it reads files and plots. Iterating on the
notebook stays cheap; re-running an expensive fit is a deliberate act.

`<slug>_run.py` is optional: if the intermediates the notebook needs are already on
disk (from a prior run of your pipeline, from a prior `/ds-validation` invocation,
or at a path the operator names), skip it and write only the notebook.

## Usage

- `/ds-validation <target> — <checks>` — e.g. `/ds-validation propensity model — histogram of predicted probabilities, overlap by treatment arm, confusion matrix at 0.5, Youden-optimal threshold`.
- `/ds-validation` with no argument — infer target and checks from the conversation. If either is unclear, **ask** — do not guess.

## Rules the agent must follow

**1. Assume the happy path.** The reviewer's environment has the packages the
analysis needs. The artifact under review is at the path the spec says. Column
names match. Neither the run script nor the notebook contains `if path.exists()`,
`try/except`, dtype `assert`s, retry loops, or "helpful" error messages. If
anything trips, the traceback is the signal.

**No `assert` statements** in either artifact unless the operator explicitly named
an assertion as one of the checks (e.g. "assert no nulls in the treated column").
Assertions are validations, and only validations the operator asked for appear.

**2. Minimum dependencies.** Use the smallest set of libraries that satisfies the
checks. If pandas handles it, don't import PySpark. If the standard library
handles it, don't import pandas. Every added dependency is one more thing the
reviewer's box has to have installed. When a check *does* need something less
common (`pyspark`, `xgboost`, `statsmodels`), verify it imports **before** writing
either artifact.

**3. Ask before guessing.** If any of the following is unclear, **stop and ask
the user one focused question** — do not paper over ambiguity with defensive
code, do not add "reasonable defaults", do not include diagnostics the operator
did not ask for:

- what artifact is under review,
- what checks the operator wants,
- what the artifact's inputs are (e.g. which CSV to score, which train/test split
  to evaluate on),
- whether the intermediates the notebook needs are already on disk, and where.

Only the checks the operator names appear in the notebook. No bonus diagnostics.

## Where files land

```
outputs/ds-validation/<slug>/
  <slug>_run.py                 # the computation (may not exist — see step 3)
  <slug>_validation.ipynb       # the diagnostics
  <run script's outputs — e.g. predictions.csv, model.pkl, metrics.json>
```

- Root is `outputs/ds-validation/`. Create it (and any parents) if it does not
  exist.
- `<slug>` is a short kebab-case name derived from the target (e.g. `propensity`,
  `slice-2-propensity`, `customer-month-schema`).
- The run script resolves its output directory as `Path(__file__).parent` — no
  absolute paths, no dependence on the reviewer's cwd.
- The notebook expects to be opened from the repo root: it loads its inputs from
  `outputs/ds-validation/<slug>/…` (relative path, resolves from wherever
  `jupyter lab` was launched).

## Notebook shape and conventions

Every notebook opens with three fixed cells, then one markdown + one code cell
per check:

1. **Title / preamble** (markdown) — one paragraph naming the artifact under
   review, the run command that produced the inputs (if a run script exists),
   and the run command that opens the notebook.
2. **Imports** (code, `id: imports`) — only the libraries the checks below
   actually use, plus `pandas`, `matplotlib.pyplot` with `%matplotlib inline`,
   and `IPython.display.display`. Nothing more.
3. **Setup** (code, `id: setup`) — one cell that reads the intermediates from
   `outputs/ds-validation/<slug>/` (or the operator-named path) and prints a
   shape/`head()` for confirmation. Nothing else.
4. **Analysis cells** — one `## N. <what this checks>` markdown header, then one
   code cell per idea, IDed as `stage-N-<slug>`.

Conventions:

- **Stable `id` on every code cell.** Reviewers navigate by ID.
- **One idea per cell.** If a cell exceeds ~20 lines, split it.
- **`display(df)` for tables**, not `print(df)`.
- **No progress bars, no `try/except`, no asserts.**
- Every axis has a label; every plot has a title; every multi-series plot has a
  legend. `plt.tight_layout()` at the end of each figure cell.
- One figure per cell (or one `plt.subplots(...)` grid per cell).

`%matplotlib inline` and a single `plt.rcParams.update({...})` (figsize, dpi,
grid alpha) both live in the imports cell.

## Protocol

**0. Resolve target and checks.** Name the artifact under review and enumerate
the checks. If either is unclear, ask one question before proceeding.

**1. Verify prereqs.** Before writing anything:

- confirm `jupyter` is available (`jupyter --version`),
- confirm every package the run script and the notebook will import is
  installed (a one-line `python -c "import a, b, c"` is enough),
- confirm project modules the run script will call are importable.

If anything is missing, **stop and tell the operator what to install**. Do not
add fallbacks, do not swap in an alternative library, do not proceed.

**2. Pick the slug and the output folder.** Kebab-case slug from the target.
Ensure `outputs/ds-validation/<slug>/` exists.

**3. Check for existing intermediates.** Enumerate the files the notebook will
consume for the requested checks. Look for them, in this order:

- **conversation context first** — prior turns in this session may already name
  where a run landed (e.g. "I just fit the propensity model, artifacts are at
  `data/processed/`"). Prefer explicit context to guessing.
- `outputs/ds-validation/<slug>/` — a prior `/ds-validation` invocation may have
  already populated it.
- any other path the operator named in the invocation.

If every required intermediate is already accounted for, **skip steps 4 and 5** —
the notebook loads them from wherever they live. Note the skip in the surface
message. If some but not all are present, ask the operator which set to use
rather than partially regenerating.

**4. Write `<slug>_run.py`.** Keep it as simple as possible: straight-line
code in `main()`, hardcoded paths, no `argparse`/`click`/CLI flags, no config
plumbing, no factory functions. It does the computation the operator named in
the smallest number of steps, using the minimum dependencies, and writes each
intermediate the notebook will consume to `Path(__file__).parent`. Prefer plain
formats (`.csv` for tables, `.pkl` for fitted estimators, `.json` for scalars
and small dicts). Name outputs after what they are (`predictions.csv`,
`propensity_model.pkl`), not after the check that consumes them.

Include **minimal progress logging** — one `print(...)` line before each major
step (load, transform, fit, predict, write). Enough for the operator to see
where the run is stuck if a stage takes a while. No progress bars, no `tqdm`,
no per-row logging.

**5. Execute `<slug>_run.py`.** Run it from the repo root in a way that both
the operator and you can watch progress in real time — the `print(...)` lines
from step 4 must reach the operator's terminal as they happen, not in one dump
at the end. In practice: run it in the foreground with a generous timeout, or
background it with output-monitoring on the "Loading …", "Fitting …", "Done."
lines. Do not fire-and-forget and check back at the end; if a step hangs, both
parties need to see where.

When it exits:

- on success: report the intermediates it produced (one line each) and hand the
  operator the notebook launch command,
- on failure: surface the traceback verbatim and stop. Do not attempt to fix,
  do not re-run — that's the operator's call.

**6. Write `<slug>_validation.ipynb`.** Three fixed cells + one markdown/code
pair per requested check. The setup cell loads from wherever the intermediates
actually landed (from the run script, from `outputs/ds-validation/<slug>/`, or
from an operator-named path). Do not include checks the operator did not ask
for.

**7. Surface the result.** Report to the user, in this order:

- whether the run script was written and run, or skipped (with the reason),
- the intermediate files consumed by the notebook and where they live,
- the notebook launch command: `jupyter lab outputs/ds-validation/<slug>/<slug>_validation.ipynb`,
- the stages in the notebook (one line each),
- any check whose interpretation you had to fix in place of asking (should be
  rare — prefer asking in step 0).

Do not commit, do not open a PR, do not auto-iterate. If the reviewer wants a
check changed or added, they edit the notebook or re-invoke `/ds-validation`
with a delta.

## Templates

### `<slug>_run.py`

Straight-line `main()`. Hardcoded paths. No `argparse`, no config, no CLI
flags. One `print(...)` before each major step so both the agent (streaming)
and the operator (watching the terminal) can see where the run is.

```python
"""Compute the inputs that <slug>_validation.ipynb consumes.

Produces (in this folder):
  - <name>.csv — <one line>
  - <name>.pkl — <one line>
"""
from __future__ import annotations

from pathlib import Path

# check-specific imports only — no defensive fallbacks

OUT = Path(__file__).parent


def main() -> None:
    print("Loading <inputs> ...")
    # ...

    print(f"Fitting <thing> on {n:,} rows ...")
    # ...

    print("Writing <name>.csv, <name>.pkl ...")
    # ...

    print("Done.")


if __name__ == "__main__":
    main()
```

### Notebook — title cell (markdown)

````markdown
# <artifact> validation

**Purpose.** One paragraph naming the artifact under review and the invariants
the checks below verify.

**Reproduce inputs.** `<slug>_run.py` in this folder produces the intermediates
from scratch (omit this block if the intermediates were not produced by a run
script):

```bash
python outputs/ds-validation/<slug>/<slug>_run.py
```

**Open notebook.**

```bash
jupyter lab outputs/ds-validation/<slug>/<slug>_validation.ipynb
```
````

### Notebook — imports cell (`id: imports`)

```python
from __future__ import annotations
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from IPython.display import display

# check-specific imports here — only what the analysis cells below use.

%matplotlib inline
plt.rcParams.update({"figure.figsize": (9, 4), "figure.dpi": 110, "axes.grid": True, "grid.alpha": 0.3})
pd.set_option("display.max_columns", 50)

OUT = Path("outputs/ds-validation/<slug>")
```

### Notebook — setup cell (`id: setup`)

```python
# Load the intermediates.
predictions = pd.read_csv(OUT / "predictions.csv")

print(f"{predictions.shape[0]:,} rows × {predictions.shape[1]} cols")
display(predictions.head())
```

### Notebook — analysis stage (repeat per check)

Markdown cell:

````markdown
## N. <what this check verifies>

<one line naming the invariant or diagnostic — what a "pass" looks like>
````

Code cell:

```python
# stage-N-<slug>
<the check — one idea, ≤~20 lines, terminates in a display() or a plot>
```

## Principles

- **Split run from analysis so the notebook always reruns fast.** Heavy compute
  lives in `<slug>_run.py`; the notebook reads its outputs.
- **Check disk before recomputing.** A run script that isn't needed shouldn't
  be written.
- **Happy path, always.** Defensive code obscures the signal the reviewer came
  for. No asserts unless the operator asked for one.
- **Minimum dependencies.** Every added import is one more thing the reviewer's
  box has to have installed.
- **Only the diagnostics the operator asked for.** Ask before guessing; never
  fill gaps with plausible defaults.
- **Run the compute; author the notebook.** The agent runs `<slug>_run.py` and
  reports completion; the reviewer opens the notebook.
- **Author, don't iterate.** Single pass; the user re-invokes with a delta.
