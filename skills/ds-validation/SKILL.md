---
name: ds-validation
description: >-
  Author a validation for a piece of data-science work as a single
  <slug>_validation.ipynb under outputs/ds-validation/<slug>/. Each validation
  section has two subsections: Na gets and transforms data (checking disk for
  existing artefacts before any long-running work), Nb runs the exit gate the
  operator asked for. Assume the happy path — no try/except, no schema asserts.
  The only path.exists() guard is in Na-get cells, so re-running validation
  never restarts finished compute. No assert statements unless the operator
  explicitly asks for one as a check. Use the minimum set of dependencies that
  satisfies the checks — do not reach for Spark if pandas works. Include only
  the diagnostics the operator asked for; if a check is ambiguous, ask before
  guessing. The agent verifies prereqs, writes the notebook, and hands the
  operator the launch command on completion. All notebook paths are absolute —
  anchored at `REPO_ROOT` resolved at authoring time — so cells work regardless
  of where `jupyter lab` was launched. Pre-existing upstream artefacts are read
  in place; never copied into the validation folder. Use only when the user
  explicitly invokes /ds-validation with a target and a checks list — never
  auto-invoke from ambient context.
---

# /ds-validation — one inline validation notebook

Every `/ds-validation` run produces **one artifact**:

- `<slug>_validation.ipynb` — co-located compute and exit-gate checks under
  `outputs/ds-validation/<slug>/`.

Heavy work lives **inside the notebook**, not in a separate run script. Each
validation section is split into two subsections so you can iterate on gates
without re-running finished upstream work:

- **Na — get and transform.** Check disk for artefacts **before** any
  long-running step. If the artefact is already there, load it and skip the
  expensive fetch/fit. Then transform (always — so you can inspect the steps)
  and preview (`head()` / `display()`).
- **Nb — validate.** The exit gate the operator asked for. Reruns fast because
  Na skipped compute when artefacts were on disk.

Artefacts the notebook **creates** (fetch, fit, transform outputs — CSVs, JSON,
pickles, …) land in `OUT`. Pre-existing upstream artefacts are **read in place**
via absolute paths — never copied into `OUT`. Later sections reuse
notebook-produced artefacts via the Na-get disk check.

## Usage

- `/ds-validation <target> — <checks>` — e.g. `/ds-validation propensity model — histogram of predicted probabilities, overlap by treatment arm, confusion matrix at 0.5, Youden-optimal threshold`.
- `/ds-validation` with no argument — infer target and checks from the conversation. If either is unclear, **ask** — do not guess.

## Rules the agent must follow

**1. Assume the happy path.** The reviewer's environment has the packages the
analysis needs. The artifact under review is at the path the spec says. Column
names match. No `try/except`, dtype `assert`s, retry loops, or "helpful" error
messages. If anything trips, the traceback is the signal.

**The one exception: `path.exists()` in Na-get cells** — and only when the
notebook **produces** the artefact into `OUT`. Each such get cell checks
whether the artefact is already on disk before running anything expensive. That
guard is required, not defensive — it is how the notebook avoids restarting
long-running tasks when results are already materialised. Na-get cells that
read pre-existing upstream artefacts do not use existence checks. No other cell
uses existence checks.

**No `assert` statements** unless the operator explicitly named an assertion as
one of the checks (e.g. "assert no nulls in the treated column"). Assertions are
validations, and only validations the operator asked for appear in Nb cells.

**2. Minimum dependencies.** Use the smallest set of libraries that satisfies the
checks. If pandas handles it, don't import PySpark. If the standard library
handles it, don't import pandas. Every added dependency is one more thing the
reviewer's box has to have installed. When a check *does* need something less
common (`pyspark`, `xgboost`, `statsmodels`), verify it imports **before** writing
the notebook.

**3. Ask before guessing.** If any of the following is unclear, **stop and ask
the user one focused question** — do not paper over ambiguity with defensive
code, do not add "reasonable defaults", do not include diagnostics the operator
did not ask for:

- what artifact is under review,
- what checks the operator wants,
- what the artifact's inputs are (e.g. which CSV to score, which train/test split
  to evaluate on),
- whether artefacts are already on disk, and where,
- what each Na-get cell produces into `OUT` (skip-if-present applies only to
  notebook-owned compute, not upstream reads).

Only the checks the operator names appear in the notebook. No bonus diagnostics.

**4. Absolute paths only.** Relative paths and `Path.cwd()` break when Jupyter is
launched from a subdirectory or the IDE sets a different kernel cwd — the failure
mode is `FileNotFoundError` on artefact reads and `ModuleNotFoundError` on project
imports. Every path the notebook touches must be absolute:

- **`REPO_ROOT`** — the git repo root, resolved by the agent at authoring time and
  embedded as a literal `Path("…")` in the imports cell. Do not leave path
  construction to runtime cwd discovery.
- **`OUT`** — `(REPO_ROOT / "outputs/ds-validation/<slug>").resolve()` (or the
  operator-named root under `REPO_ROOT`).
- **Upstream inputs** — `(REPO_ROOT / "<path-from-repo-root>").resolve()`, never a
  bare relative string passed to `read_csv` / `open`.
- **Project imports** — `sys.path.insert(0, str(<absolute src dir>))` before any
  `import <project_package>`; verify importability with that absolute path during
  prereq check.

Downstream cells use `OUT / "file.csv"` or other variables built in the imports
cell — never `Path("outputs/…")` or `Path("../…")` inline.

**5. Read upstream in place; never copy.** Pre-existing artefacts (pipeline
CSVs, prior model outputs, tables fetched elsewhere) are referenced by absolute
path and read directly. Do not `shutil.copy`, `cp`, or re-write them into
`OUT` — that duplicates data and obscures which file is canonical. The Na-get
disk check applies only to **expensive work the notebook owns** (API pull, SQL
extract, model fit): if the artefact is not on disk, compute it and write to
`OUT`; if it is, load and skip. When validating something that already exists
upstream, Na-get loads from the upstream path; `OUT` holds only derived
artefacts the notebook produces.

## Where files land

```
outputs/ds-validation/<slug>/
  <slug>_validation.ipynb       # the only authored artifact
  <notebook-produced artefacts> # e.g. predictions.csv, scored.csv, model.pkl
```

Upstream pipeline artefacts stay where they already live (e.g.
`outputs/data/foo.csv`) — the notebook points at them; it does not copy them
here.

- Root is `outputs/ds-validation/`. Create it (and any parents) if it does not
  exist. The operator may name a different root (e.g. a project-local
  `outputs/validation/`); honour it when given.
- **Gitignore the output root.** Before writing the notebook, check the repo's
  `.gitignore`. If the resolved root (default `outputs/ds-validation/`) is not
  already excluded, append it — validation notebooks and artefacts are local
  scratch, not commit material.
- `<slug>` is a short kebab-case name derived from the target (e.g. `propensity`,
  `slice-2-propensity`, `stage-1-pr-extract`).
- The imports cell sets `REPO_ROOT` (absolute) and `OUT = (REPO_ROOT /
  "outputs/ds-validation/<slug>").resolve()`. Every file read, write, and project
  import is built from those anchors — never from cwd-relative strings.

## Notebook shape and conventions

Every notebook opens with two fixed cells, then **one block per requested check**.
Each block has a section header, an Na subsection (three code cells), and an Nb
subsection (one code cell):

1. **Title / preamble** (markdown) — one paragraph naming the artifact under
   review, the invariants the checks verify, and the command to open the
   notebook. List upstream paths the notebook reads in place (absolute).
2. **Imports** (code, `id: imports`) — only the libraries the checks below
   actually use, plus `pandas` and `IPython.display.display`. Add
   `matplotlib.pyplot` with `%matplotlib inline` only when a check needs a
   plot. Set `REPO_ROOT` to the workspace's resolved absolute path and
   `OUT = (REPO_ROOT / "outputs/ds-validation/<slug>").resolve()` (or the
   operator-named root under `REPO_ROOT`). Add `sys.path.insert(0, …)` with an
   absolute src directory when the notebook imports project modules. Define
   **upstream input paths** here as `(REPO_ROOT / "…").resolve()` — these are
   read in place, never copied to `OUT`.

Then, **for each check N**:

3. **Section header** (markdown) — `## N. <what this section validates>`
4. **Na header** (markdown) — `### Na. Get and transform` plus one line on
   what artefact the get cell loads or produces and what the transform outputs.
5. **Na-get** (code, `id: stage-Na-get`) — two cases only:
   - **Upstream already exists:** load from the absolute upstream path (set in
     imports). No copy, no `OUT` write, no disk check — prereq step confirmed
     the file is there.
   - **Notebook must produce it:** if the artefact is not in `OUT`, run the long
     step (API pull, model fit, …) and write to `OUT`; otherwise load and print
     that the existing file is being reused.
6. **Na-transform** (code, `id: stage-Na-transform`) — transform raw/loaded
   data into the frame or summary the Nb cell will consume. Always runs, even
   when the get cell skipped — this is where the operator inspects intermediate
   logic. Write any derived artefacts this section owns to `OUT`.
7. **Na-preview** (code, `id: stage-Na-preview`) — `print` shape (or scalar
   summary) and `display(df.head())` (or `display(...)` for the object under
   review). Nothing else.
8. **Nb header** (markdown) — `### Nb. Validate` plus one line naming what a
   pass looks like.
9. **Nb-validate** (code, `id: stage-Nb-<slug>`) — the exit gate. One idea,
   terminates in `display()` or a plot.

Conventions:

- **Stable `id` on every code cell.** Reviewers navigate by ID.
- **One idea per cell.** If a cell exceeds ~20 lines, split it.
- **`display(df)` for tables**, not `print(df)` — except shape/scalar lines in
  preview cells.
- **No progress bars, no `try/except`, no asserts** (except operator-requested
  assertions in Nb cells).
- Every axis has a label; every plot has a title; every multi-series plot has a
  legend. `plt.tight_layout()` at the end of each figure cell.
- One figure per cell (or one `plt.subplots(...)` grid per cell).

`%matplotlib inline` and a single `plt.rcParams.update({...})` (figsize, dpi,
grid alpha) both live in the imports cell when matplotlib is imported.

### Sharing artefacts across sections

When several checks consume the same **upstream** table, all sections reference
the same absolute path from the imports cell — no per-section copy. When
several checks consume a **notebook-produced** artefact, each section still gets
its own Na/Nb pair; later Na-get cells point at the same `OUT` path, find it on
disk, and skip the long run. Na-transform in those sections may be a short load
or a slice of what section 1 already wrote; keep it explicit so the operator can
read the dependency chain top to bottom.

## Protocol

**0. Resolve target and checks.** Name the artifact under review and enumerate
the checks. For each check, name the artefact its Na-get cell should skip on.
If anything is unclear, ask one question before proceeding.

**1. Resolve `REPO_ROOT`.** Determine the git repo root from the workspace (look
for `.git` / `pyproject.toml`). All paths in the notebook will be anchored here.

**2. Verify prereqs.** Before writing anything:

- confirm `jupyter` is available (`jupyter --version`),
- confirm every package the notebook will import is installed (a one-line
  `python -c "import a, b, c"` is enough),
- confirm project modules the notebook will call are importable via the absolute
  `sys.path` entry the imports cell will use,
- confirm upstream artefact paths exist at their `(REPO_ROOT / "…").resolve()`
  locations when the notebook reads pre-existing files.

If anything is missing, **stop and tell the operator what to install**. Do not
add fallbacks, do not swap in an alternative library, do not proceed.

**3. Pick the slug and the output folder.** Kebab-case slug from the target.
Ensure `outputs/ds-validation/<slug>/` exists (or the operator-named root).
Ensure that root's parent directory is in `.gitignore` (default:
`outputs/ds-validation/`); add the entry if missing.

**4. Inventory existing artefacts.** Before writing the notebook, look for files
already on disk — using absolute paths:

- **upstream inputs** the notebook will read in place (must exist when validating
  pre-built artefacts),
- **notebook-produced artefacts** in `(REPO_ROOT / "outputs/ds-validation/<slug>/").resolve()`
  from a prior `/ds-validation` invocation (Na-get will skip recompute),
- any other path the operator named, resolved under `REPO_ROOT` when relative.

Note what is already on disk in the surface message. Do not copy upstream files
into `OUT` during inventory or in the notebook.

**5. Write `<slug>_validation.ipynb`.** Two fixed cells, then one Na/Nb block
per requested check. Na-get cells implement the disk check. Embed absolute
paths only. Do not include checks the operator did not ask for.

**6. Surface the result.** Report to the user, in this order:

- `REPO_ROOT` used in the notebook,
- upstream paths read in place (canonical locations — not copied),
- notebook-produced artefacts already on disk (and which Na-get cells will skip),
- notebook-produced artefacts the notebook will create on first run,
- the notebook launch command (absolute path — works from any cwd):
  `jupyter lab <REPO_ROOT>/outputs/ds-validation/<slug>/<slug>_validation.ipynb`,
- the sections in the notebook (one line each: Na artefact + Nb gate),
- any check whose interpretation you had to fix in place of asking (should be
  rare — prefer asking in step 0).

Do not commit, do not open a PR, do not auto-iterate. The operator opens the
notebook, runs Na cells once (or watches them skip), then reruns Nb cells
freely. If a check needs changing, they edit the notebook or re-invoke
`/ds-validation` with a delta.

## Templates

### Notebook — title cell (markdown)

````markdown
# <artifact> validation

**Purpose.** One paragraph naming the artifact under review and the invariants
the checks below verify.

**Upstream artefacts.** Name any inputs that already exist outside this folder
(omit if everything is produced inside the notebook):

- `/absolute/path/to/raw.csv` — <one line>

**Open notebook.**

```bash
jupyter lab /absolute/path/to/repo/outputs/ds-validation/<slug>/<slug>_validation.ipynb
```
````

### Notebook — imports cell (`id: imports`)

```python
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd
from IPython.display import display

# Agent resolves REPO_ROOT from the workspace at authoring time — literal absolute path.
REPO_ROOT = Path("/absolute/path/to/repo")
OUT = (REPO_ROOT / "outputs/ds-validation/<slug>").resolve()
OUT.mkdir(parents=True, exist_ok=True)

# Only when importing project modules — absolute src dir, verified in prereq check.
# sys.path.insert(0, str((REPO_ROOT / "projects/<pkg>/src").resolve()))

# Upstream inputs — read in place; never copy to OUT.
UPSTREAM = (REPO_ROOT / "path/from/repo/root.csv").resolve()

# check-specific imports here — only what the cells below use.
# import matplotlib.pyplot as plt  # only when a check plots
# from <project_package> import ...  # after sys.path.insert above
```

When plots are needed, add to the imports cell:

```python
import matplotlib.pyplot as plt

%matplotlib inline
plt.rcParams.update({"figure.figsize": (9, 4), "figure.dpi": 110, "axes.grid": True, "grid.alpha": 0.3})
pd.set_option("display.max_columns", 50)
```

### Notebook — one validation section (repeat per check)

Two Na-get patterns — use the one that matches the section:

**A. Validating a pre-existing upstream artefact** (read in place):

Markdown — Na header:

```markdown
### 1a. Get and transform

Load `<upstream file>` from its canonical path. Transform produces `<what Nb consumes>`.
```

Code — Na-get (`id: stage-1a-get`):

```python
raw = pd.read_csv(UPSTREAM)
```

**B. Notebook produces the artefact** (disk check in `OUT`):

Markdown — section header:

```markdown
## 1. <what this section validates>
```

Markdown — Na header:

```markdown
### 1a. Get and transform

Skip the fetch when `<artefact>` already exists in `OUT`. Transform produces
`<what Nb consumes>`.
```

Code — Na-get (`id: stage-1a-get`):

```python
RAW = OUT / "raw_table.csv"

if RAW.exists():
    print(f"Using existing {RAW}")
    raw = pd.read_csv(RAW)
else:
    print(f"Fetching raw data → {RAW}")
    # long-running step: API calls, SQL pull, model fit, pipeline stage, …
    # raw = ...
    raw.to_csv(RAW, index=False)
```

Code — Na-transform (`id: stage-1a-transform`):

```python
# Transform always runs — inspect logic here.
ready = raw.assign(score=...)  # example
ready.to_csv(OUT / "scored.csv", index=False)
```

Code — Na-preview (`id: stage-1a-preview`):

```python
print(f"{ready.shape[0]:,} rows × {ready.shape[1]} cols")
display(ready.head())
```

Markdown — Nb header:

```markdown
### 1b. Validate

Pass when <one-line pass condition>.
```

Code — Nb-validate (`id: stage-1b-<slug>`):

```python
status = "PASS" if <condition> else "FAIL"
display(pd.DataFrame({"check": ["<gate name>"], "status": [status]}))
```

### Example — later section reusing an upstream artefact

Section 2 reads the same `UPSTREAM` path from imports — no copy, no `OUT` write:

```python
raw = pd.read_csv(UPSTREAM)
ids = raw["id"]
```

### Example — later section reusing a notebook-produced artefact

Section 2's Na-get points at `SCORED` in `OUT` (written by section 1). The long
run is skipped; transform loads the derived artefact directly:

```python
SCORED = OUT / "scored.csv"

if SCORED.exists():
    print(f"Using existing {SCORED}")
    ready = pd.read_csv(SCORED)
else:
    raise RuntimeError("Run section 1a first — scored.csv not on disk")
```

## Principles

- **Inline compute; disk check before heavy work.** Na-get cells are the only
  place that tests `path.exists()`. Finished artefacts are never recomputed
  unless the operator deletes them.
- **Transform and preview are always visible.** Na-transform and Na-preview run
  every time so the operator can verify intermediate logic before trusting Nb.
- **Happy path, always.** Defensive code outside Na-get obscures the signal
  the reviewer came for. No asserts unless the operator asked for one.
- **Minimum dependencies.** Every added import is one more thing the reviewer's
  box has to have installed.
- **Only the diagnostics the operator asked for.** Ask before guessing; never
  fill gaps with plausible defaults.
- **Author the notebook; the operator runs it.** The agent does not execute
  long-running cells — the notebook's Na-get guards handle skip vs run when the
  operator executes it.
- **Author, don't iterate.** Single pass; the user re-invokes with a delta.
- **Gitignore the output root.** Notebooks and artefacts under
  `outputs/ds-validation/` are operator-local; ensure `.gitignore` excludes the
  root before writing files.
- **Read upstream in place; never copy.** Pipeline artefacts stay where they
  were produced. `OUT` is only for work the notebook owns.
- **Absolute paths only.** `REPO_ROOT` is embedded at authoring time; `OUT` and
  every upstream input are `.resolve()`d from it. No cwd-relative paths, no
  runtime repo discovery — that is what causes `FileNotFoundError` and import
  failures when Jupyter's cwd differs from the repo root.
