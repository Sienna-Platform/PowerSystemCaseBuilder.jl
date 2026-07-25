# SDD Plan A — PowerSystemCaseBuilder: green tests on the transformer refactor

Parent analysis: `PowerNetworkMatrices.jl/.claude/plans/2026-07-24-transformer-refactor-distribution.md`
Repo: `/Users/jdlara/cache/PowerSystemCaseBuilder.jl`, branch `psy6`.
Goal: PSB test suite passes against PSY `psy6` @ `d19f3244f`.

**This plan is independent of Plan B (PNM) and may run in parallel.** PSB's *root*
`Project.toml` already pins PSY `psy6` correctly; only `test/Project.toml` is stale. So PSB
as a *dependency* is already correct, and PNM does not wait on this plan.

## Context

The transformer code already landed in PSB `origin/psy6` (PR #200 `mb/transformer-refactor`).
Local `psy6` is 10 commits behind. What remains is environment correctness plus whatever the
suite reveals. See the parent analysis §1 for the API change; the short version PSB cares
about: five concrete transformer types were deleted, replaced by `TwoWindingTransformer` /
`ThreeWindingTransformer`, each holding one or three `TransformerCircuit` objects.

## Global Constraints

Bind every task. A reviewer treats a violation as a defect.

1. **Always `julia --project=test`** — never bare `--project`, never bare `julia`. Test deps
   live in `test/Project.toml`.
2. **Subagents never run the full suite.** PSB builds and serializes real systems; the full
   run is multi-minute-to-tens-of-minutes and downloads artifacts. Implementers run scoped
   single-file runs only:
   `julia --project=test test/runtests.jl test_transformer_parsing`
   (`@includetests ARGS` takes bare file names, no `.jl`). Cap ~4 min. The **controller**
   runs the full suite in the background and reports results back into the loop.
3. **Zero Error-level log events.** `runtests.jl` ends with
   `@test length(IS.get_log_events(multi_logger.tracker, Logging.Error)) == 0`. A stray
   `@error` fails the suite even when all testsets pass. Never silence one by downgrading a
   legitimate error — follow the existing precedent in `357be59` ("handle expected logged
   error for isolated bus") and assert the expected error instead.
4. **No `nothing`-sentinel guards.** Do not add `x === nothing && continue` to skip
   malformed data. `TransformerCircuit`'s optional 3W pairwise fields are legitimately
   `nothing`; anything else absent is a bug that must surface.
5. **No `isa` / `<:Type` runtime checks**, including in tests — use multiple dispatch.
6. **Never `git commit` or `git push`** unless the controller says a task authorizes it (see
   Open Decision below). Leave changes unstaged; `git add -N` new files.
7. **Run the formatter** before declaring any task done:
   `julia --project=scripts/formatter -e 'include("scripts/formatter/formatter_code.jl")'`
8. **Do not regenerate or hand-edit PSY structs.** PSY is upstream and frozen for this plan.
   If a PSB failure traces to a genuine PSY bug, report BLOCKED — do not patch PSY.
9. **Don't `deepcopy(sys)`** for read-only access. Reserve it for testsets that mutate a
   PSB-cached system.

## Tasks

### Task 1 — Sync and correct the test environment
Mechanical. Cheap model.

Scope: `test/Project.toml`, root `Project.toml`, and a local fast-forward.

1. Fast-forward local `psy6` to `origin/psy6` (10 commits, `586f3dc` → `769b7a9`). Verify it
   is a true fast-forward first; if it is not, stop and report.
2. In `test/Project.toml` `[sources]`, repoint two stale revs:
   - `PowerSystems`: `rev = "transformer-refactor"` → `rev = "psy6"`
   - `PowerFlowFileParser`: `rev = "mb/transformer-refactor"` → `rev = "psy6"`
     (Both target branches now contain the merged work — PSY `d19f3244f`, PFFP `adf5cb1`.)
3. In root `Project.toml`, fix the `PowerTableDataParser` URL: `NLR-Sienna` → `NREL-Sienna`.
   Pre-existing typo, unrelated to transformers, but it breaks a clean instantiate.
4. `julia --project=test -e 'using Pkg; Pkg.instantiate()'`
5. Compile-check: `julia --project=test -e 'using PowerSystemCaseBuilder'`

Done when: instantiate resolves and the compile-check is clean. **Do not run tests in this
task** — that is Task 2, run by the controller.

### Task 2 — Full-suite baseline and failure triage (controller-run, no code changes)
Not a subagent task. The controller runs this in the background.

`julia --project=test test/runtests.jl` — capture all output to a file in the plan workspace.

Then dispatch one **diagnostician** subagent (standard model) whose only job is to read that
output file and produce a findings file: one entry per distinct failure with the test file,
testset name, error text, and a one-line hypothesis of root cause. It writes no code and
edits nothing.

Classify each finding into exactly one bucket:
- **(a) env/pin** — resolvable by Task 1-style config fixes
- **(b) stale test expectation** — test names a deleted type or an old field layout
- **(c) serialized-artifact drift** — cached/serialized system JSON predates the refactor
- **(d) genuine PSB source bug** against the new API
- **(e) upstream PSY bug** → BLOCKED, escalate

This task's output is the findings file. **The controller then writes Tasks 3+ from it** —
they cannot be specified in advance, because the failure set is unknown until the suite runs.
That is the honest structure for "make the tests pass" work; do not pre-invent tasks here.

### Task 3+ — Fix waves (written by the controller after Task 2)
One task per bucket, not one per failure. Batching by bucket keeps each implementer's context
coherent and avoids N agents each rebuilding the same PSB system cache.

Expected shape, to be confirmed against the findings file:
- **3a** — stale test expectations in `test_psytestsystems.jl`, `test_parsingtestsystems.jl`,
  `test_unit_system.jl`. Highest-likelihood bucket.
- **3b** — serialized-artifact round-trip. The sharpest risk in the whole plan:
  `TransformerCircuit` has hand-written `IS.serialize`/`IS.deserialize` that encode `arc` as
  a UUID and deliberately skip `base_value`. Any cached system JSON written before the
  refactor will either fail to deserialize or silently produce a circuit with a missing
  units anchor. Verify against the bumped `PowerSystemsTestData 5.0-dev2` artifact, and force
  a rebuild (`force_build=true`, or clear `data/serialized_system/`) rather than trusting a
  stale cache.
- **3c** — `TransformerCircuit` units-anchor lifecycle. `base_value` is populated when the
  transformer is attached to a System. A system built component-by-component, serialized, and
  reloaded must end with every circuit anchored. Test the round trip, not just construction.

### Final Task — Verification
Controller-run full suite, clean, plus formatter clean. No subagent.

## Test strategy

| Who | What | When |
|---|---|---|
| Implementer | one scoped file via `runtests.jl <name>`, ~4 min cap | per task |
| Implementer | `julia --project=test -e 'using PowerSystemCaseBuilder'` | after every file edit |
| Controller | full `test/runtests.jl`, backgrounded | Task 2, after each fix wave, final |

## Open Decision (controller must resolve before Task 1)

**Commits.** The SDD review mechanism diffs `BASE..HEAD`, which presumes each task commits.
The standing rule in this workspace is never to commit without explicit direction, and to
leave changes unstaged. These are incompatible as written.

For PSB the conflict is mild — the changes are small enough to review as an unstaged working
diff. Recommendation: **no commits**; reviewers get `git diff` / `git diff --stat` captured to
a file instead of a `BASE..HEAD` review package. Plan B cannot take this route (its Task 1 is
a merge commit), so decide both together.
