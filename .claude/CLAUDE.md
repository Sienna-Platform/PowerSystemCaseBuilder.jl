# PowerSystemCaseBuilder.jl (PSB) — psy6 branch

The Sienna **test-system fixture factory**: a registry of 200+ named `PSY.System` cases built from raw data (Matpower, PSSE raw/dyr, tabular CSV, PowerFlowData) with an on-disk serialized cache, so downstream test suites (PSY, PNM, PF, POM) get systems in seconds. Not an optimization package. Its serialization is PSY's own IS-based JSON+HDF5 — **not** the OpenAPI/GridDB pipeline. Platform conventions: `.claude/Sienna.md`; workspace architecture: `/home/jdlara/Sienna_work/psy6/CLAUDE.md`.

## Why this package matters platform-wide

PSB's cache is the single most cross-referenced gotcha in the Sienna stack: nearly every downstream test suite depends on its behavior. Two facts drive everything:

1. **The cache key is a SHA of the case args only** (`src/utils/utils.jl`) — there is **no invalidation on PSY/PSB version or builder-function change**. After changing PSY (or a builder), stale cached JSON is silently reused and your change "doesn't take". Clear `data/serialized_system/`, call `clear_serialized_system(s)`/`clear_all_serialized_systems()`, or pass `force_build=true`.
2. **`assign_new_uuids=true` (the default) matters** — each `build_system` call returns independent objects with fresh UUIDs. Don't set it `false` in shared runs (UUID collisions in IS containers). Mutating testsets must `deepcopy` (or rebuild); read-only ones must not.

## Build API and cache mechanics

```julia
build_system(PSITestSystems, "c_sys5"; force_build=true)   # categories: PSY/PSI/PSID/PSSEParsing/Matpower TestSystems, PSISystems, PSIDSystems, SPISystems
list_systems(...); show_systems(...); list_categories()
```

- Flow (`src/build_system.jl` + `src/utils/utils.jl`): cache check → optional artifact download → registered `build_func(; raw_data, …)` → serialize (unless `skip_serialization`) → later calls deserialize. Cache dir: `data/serialized_system/<sha256 of case-args>/<name>.json` + `_metadata.json` + `_validation_descriptors.json` + `_time_series_storage.h5`.
- `build_system` splits kwargs: keys in `PSY.SYSTEM_KWARGS` forward to `PSY.System`; the rest must match the descriptor's `supported_arguments` or error. Non-encodable `sys_args` skip caching entirely.
- Catalog: `SYSTEM_CATALOG` in `src/system_descriptor_data.jl` (~228 `SystemDescriptor` entries; duplicate names error); builders in `src/library/` (8 catalog files); include order puts the catalog last, after all builders.
- Raw data via lazy artifacts (`Artifacts.toml`): `CaseData` = PowerSystemsTestData tarball (currently a 5.0-dev tag), `rts` = RTS-GMLC. **The CaseData download can flake — retry once before digging**; there is no retry in the code. Re-pin the sha256 when PowerSystemsTestData re-tags.
- `SystemDescriptor`/`SystemBuildStats` are mutable with accessors — no dot access. Descriptors are shared mutable state across builds (audit-flagged); don't mutate them in builders.

## psy6 specifics

- Branch `psy6`; `[sources]` pins in **both** root and `test/Project.toml`: IS→`IS4`, PowerSystems→`psy6`, PowerFlowFileParser→`psy6`, PowerTableDataParser→`psy6`. ⚠️ Known pin inconsistencies to not propagate: root Project.toml points PowerTableDataParser at the org typo `NLR-Sienna` and mixes `NREL-Sienna` vs `Sienna-Platform` orgs between root and test manifests.
- **`src/utils/psy6_compat.jl` is a sanctioned exception to the no-shims policy**: method overloads accepting old `Nothing`/Float64 signatures (`ReserveDemandCurve`/`MarketBidCost`) because the pinned PowerSystemsTestData artifact still uses pre-psy6 constructor calls. Scoped to external artifact data only; include-order sensitive (after `definitions.jl`, before `system_library.jl`). Remove it when the artifact is regenerated — never widen it.
- Parsing goes through PowerFlowFileParser/PowerTableDataParser (PSY has no parsers in this line).
- Reduction fixtures (for PNM/PF/POM work): `c_sys5`/`c_sys14` reduce **nothing**; `case11_network_reductions` has real series arcs but no forecasts; matpower RTS/case24 for larger cases.
- Compat still reads PSY ^5.10 / IS ^3.2 — the `[sources]` revs, not compat, select the breaking line. No version bumps until release.

## Commands

```sh
julia --project=test -e 'using Pkg; Pkg.instantiate()'
julia --project=test test/runtests.jl                       # full suite
julia --project=test test/runtests.jl test_psisystems       # single file (@includetests, stem without .jl)
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'   # docs first time
julia --project=docs docs/make.jl
julia --project=scripts/formatter -e 'include("scripts/formatter/formatter_code.jl")'
```

Compile-check: `julia --project=/home/jdlara/Sienna_work/psy6 -e 'using PowerSystemCaseBuilder'`. Note per-package `Pkg.test()` honors this repo's own `[sources]` git pins, not the shared psy6 env — repoint `test/Project.toml` `[sources]` to local paths to test against local checkouts (restore after).

## Downstream blast radius

Every psy6 test suite consumes PSB fixtures. Changing a builder, descriptor args, or serialization behavior invalidates cached systems everywhere — announce it and expect downstream suites to need `force_build`/cache clearing. Adding a fixture: register the builder in `src/library/`, add the `SystemDescriptor`, and keep `supported_arguments` accurate (invalid arg permutations are only caught at build time).
