# PowerSystemCaseBuilder.jl (PSB) — psy6 branch

The Sienna **test-system fixture factory**: a registry of 200+ named `PSY.System` cases built from raw data (Matpower, PSSE raw/dyr, tabular CSV, PowerFlowData) with an on-disk serialized cache, so downstream test suites (PSY, PNM, PF, POM) get systems in seconds. Not an optimization package. Both building and caching go through the OpenAPI document: parsers emit one, `PSY.from_file` reads it, and the cache is PSY's `.sns` archive of it.

The shared Sienna rules load from the import below; the `sienna-dev` skill holds the cross-package
context; the `sienna-dev` and `sienna-reviewer` subagents implement and review.

@Sienna.md

## Why this package matters platform-wide

PSB's cache is the single most cross-referenced gotcha in the Sienna stack: nearly every downstream test suite depends on its behavior. Two facts drive everything:

1. **The cache key is a SHA of the case args only** (`src/utils/utils.jl`) — there is **no invalidation on PSY/PSB version or builder-function change**. After changing PSY (or a builder), stale cached JSON is silently reused and your change "doesn't take". Clear `data/serialized_system/`, call `clear_serialized_system(s)`/`clear_all_serialized_systems()`, or pass `force_build=true`.
2. **`assign_new_uuids=true` (the default) matters** — each `build_system` call returns independent objects with fresh UUIDs. Don't set it `false` in shared runs (UUID collisions in IS containers). Mutating testsets must `deepcopy` (or rebuild); read-only ones must not.

## Build API and cache mechanics

```julia
build_system(PSITestSystems, "c_sys5"; force_build=true)   # categories: PSY/PSI/PSID/PSSEParsing/Matpower TestSystems, PSISystems, PSIDSystems, SPISystems
list_systems(...); show_systems(...); list_categories()
```

- Flow (`src/build_system.jl` + `src/utils/utils.jl`): cache check → optional artifact download → registered `build_func(; raw_data, …)` → serialize (unless `skip_serialization`) → later calls deserialize. Cache entry: `data/serialized_system/<sha256 of case-args>/<name>.sns`, written by `PSY.to_file`.
- `build_system` splits kwargs: keys in `PSY.SYSTEM_KWARGS` forward to `PSY.System`; the rest must match the descriptor's `supported_arguments` or error. Non-encodable `sys_args` skip caching entirely.
- Catalog: `SYSTEM_CATALOG` in `src/system_descriptor_data.jl` (~228 `SystemDescriptor` entries; duplicate names error); builders in `src/library/` (8 catalog files); include order puts the catalog last, after all builders.
- Raw data via lazy artifacts (`Artifacts.toml`): `CaseData` = PowerSystemsTestData tarball (tag pinned in `Artifacts.toml`), `rts` = RTS-GMLC. **The CaseData download can flake — retry once before digging**; there is no retry in the code. Re-pin the sha256 when PowerSystemsTestData re-tags.
- `SystemDescriptor`/`SystemBuildStats` are mutable with accessors — no dot access. Descriptors are shared mutable state across builds (audit-flagged); don't mutate them in builders.

## The transformer refactor and the cache

The single highest-risk interaction between this package and the psy6 line. PSY replaced five concrete transformer types with two — `Transformer2W`/`TapTransformer`/`PhaseShiftingTransformer` → `TwoWindingTransformer`, `Transformer3W`/`PhaseShiftingTransformer3W` → `ThreeWindingTransformer` — and moved all series data onto a nested `TransformerCircuit` (one per 2W, three per 3W, joined at `star_bus`).

Why PSB feels this harder than other packages: **the cache stores serialized systems and has no version-aware invalidation** (see above). Every cached JSON written before the refactor encodes the deleted type names and the old flat field layout, and `TransformerCircuit` has hand-written `IS.serialize`/`IS.deserialize` that encode `arc` as a UUID and deliberately omit `base_value`. A stale cache therefore fails to deserialize, or — worse — yields circuits with no units anchor, whose explicit-units getters misbehave with no error. **Clear `data/serialized_system/` after any transformer-touching PSY change**; do not trust a passing suite that ran off a warm cache.

- Availability is derived, not stored: `get_available(t) = any(get_available, get_circuits(t))`, and `set_available!(t, val)` cascades to every circuit. A builder that sets availability on a transformer touches all of its circuits.
- Builders constructing transformers must go through `add_component!` before any code reads an impedance — `base_value` is populated on attach.
- Transformer parsing coverage lives in `test/test_transformer_parsing.jl`; the CaseData artifact is pinned in `Artifacts.toml`.

## psy6 specifics

- Branch `psy6`; `[sources]` pins in **both** root and `test/Project.toml`: IS→`IS4`, PowerSystems→`psy6`, PowerFlowFileParser→`psy6`, PowerTableDataParser→`psy6`. The PowerTableDataParser pin uses `NLR-Sienna/PowerTableDataParser.jl`, and the others use `Sienna-Platform/*`. **`NLR-Sienna` is correct, not a typo**: `Sienna-Platform/PowerTableDataParser.jl` is a 404. Verify with `curl -sI` before you "correct" a URL.
- Parsing goes through PowerFlowFileParser/PowerTableDataParser (PSY has no parsers in this line). Every PSS/E, Matpower and tabular case builds via `system_from_openapi` (`src/parsers/openapi_pipeline.jl`): parser → OpenAPI document → `PSY.from_file`. `.dyr` cases pass the file to `system_from_openapi(pm_data, dyr_file)`, which reads it with `PowerFlowFileParser.parse_dyr` and carries the dynamic models in the document.
- Reduction fixtures (for PNM/PF/POM work): `c_sys5`/`c_sys14` reduce **nothing**; `case11_network_reductions` has real series arcs but no forecasts; matpower RTS/case24 for larger cases.
- Compat still reads PSY ^5.10 / IS ^3.2 — the `[sources]` revs, not compat, select the breaking line. No version bumps until release.

## Commands

```sh
julia --project=test -e 'using Pkg; Pkg.instantiate()'   # whole setup; test/Project.toml path-pins this checkout
julia --project=test test/runtests.jl                       # full suite
julia --project=test test/runtests.jl test_psisystems       # single file (@includetests, stem without .jl)
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'   # docs first time
julia --project=docs docs/make.jl
julia --project=scripts/formatter -e 'include("scripts/formatter/formatter_code.jl")'
```

Compile-check: `julia --project -e 'using PowerSystemCaseBuilder'`. Note per-package `Pkg.test()` honors this repo's own `[sources]` git pins — repoint `test/Project.toml` `[sources]` to local paths to test against local checkouts (restore after).

## Downstream blast radius

Every psy6 test suite consumes PSB fixtures. Changing a builder, descriptor args, or serialization behavior invalidates cached systems everywhere — announce it and expect downstream suites to need `force_build`/cache clearing. Adding a fixture: register the builder in `src/library/`, add the `SystemDescriptor`, and keep `supported_arguments` accurate (invalid arg permutations are only caught at build time).
