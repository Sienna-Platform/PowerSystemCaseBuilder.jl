# PowerSystemCaseBuilder.jl — Claude Guide

Platform-wide Sienna conventions (performance, type stability, formatter, environments, code style) live in `.claude/Sienna.md` — read it too. This file is repo-specific and does not restate them.

## Purpose & place in the stack

PowerSystemCaseBuilder (PSB / PSCB) is a **utility package that builds ready-made `PowerSystems.System` test cases** from a catalog of descriptors plus data artifacts. It is **not** a JuMP/optimization package — it constructs `System` objects only.

- `version = "2.3.0"`. Deps verified from `Project.toml`: `PowerSystems` (`^5.10`), `InfrastructureSystems` (`^3.2`), plus `CSV`, `DataFrames`, `DataStructures`, `Dates`, `DocStringExtensions`, `Downloads`, `HDF5`, `JSON3`, `LazyArtifacts`, `PrettyTables`, `Random`, `SHA`, `TimeSeries`. Julia `^1.10`.
- Built on PowerSystems/InfrastructureSystems; in the module, `const PSY = PowerSystems`, `const IS = InfrastructureSystems`. `abstract type PowerSystemCaseBuilderType <: IS.InfrastructureSystemsType`.
- **Consumed pervasively by other Sienna packages' TEST environments** (PowerSimulations, PowerSimulationsDynamics, PowerFlows, SiennaPRASInterface, …) to get realistic `System`s without re-hand-building them. Its shared-state/serialization behavior is therefore a platform-wide gotcha — see below.

> NOTE on seed memory: this clone targets **PSY v5 / IS v3** (`^5.10` / `^3.2`). The PSY-v6/IS-v4 migration notes and the "PSCB absorbed the PSY5 parsers" notes in the durable memory do **not** match this checkout — there are no `src/parsers/` files here, and builders live entirely in `src/library/`. Those notes are dropped as stale for this version.

## The `build_system` API and the catalog mechanism

Entry point (`src/build_system.jl`):

```julia
build_system(category::Type{<:SystemCategory}, name::String, print_stat=false;
             force_build=false, assign_new_uuids=true,
             skip_serialization=false, system_catalog=SystemCatalog(SYSTEM_CATALOG), kwargs...)
```

- **`category`** is a singleton subtype of `SystemCategory` (defined in the module file): `PSYTestSystems`, `PSITestSystems`, `PSIDTestSystems`, `PSSEParsingTestSystems`, `MatpowerTestSystems` (test categories), and `PSISystems`, `PSIDSystems`, `SPISystems` (example categories). All exported.
- **`SYSTEM_CATALOG`** (`src/system_descriptor_data.jl`, ~228 `SystemDescriptor` entries; README says "over 200") is the flat `Vector{SystemDescriptor}`. `SystemCatalog` (`src/system_catalog.jl`) indexes it into `Dict{DataType, Dict{String, SystemDescriptor}}` keyed by category then name; the constructor errors on duplicate names.
- **`SystemDescriptor`** (`src/system_descriptor.jl`, mutable) carries `name`, `description`, `category`, `raw_data` path, a `build_function::Function`, optional `download_function`, `stats`, and `supported_arguments::Vector{SystemArgument}`. Per-case kwargs are validated against `supported_arguments`; `SystemArgument` enforces a non-empty `allowed_values` set.
- **Library builders** live in `src/library/*.jl` (`psi_library.jl`, `psid_library.jl`, `spi_library.jl`, `matpowertest_library.jl`, `pssetest_library.jl`, `psytest_library.jl`, `psitest_library.jl`, `psidtest_library.jl`). Each `build_*` takes `(; raw_data, sys_kwargs..., <supported args>)` and returns a `System`. Data-construction `.jl` files are `include`d from the artifact at the top of `system_descriptor_data.jl`.
- Discovery helpers (exported): `list_categories`, `show_categories`, `list_systems`, `show_systems`.
- `build_system` splits user kwargs into **system kwargs** (`filter_kwargs` keeps only keys in `PSY.SYSTEM_KWARGS`, forwarded to `PSY.System`) and **case kwargs** (matched to the descriptor's `supported_arguments`); any leftover key errors out.

## Data artifacts

Data is **not** in the repo — it is fetched via lazy Julia artifacts (`Artifacts.toml`, `LazyArtifacts`). Resolved in `src/definitions.jl`:

- `DATA_DIR = artifact"CaseData"/PowerSystemsTestData-4.0.3` (from `Sienna-Platform/PowerSystemsTestData` tag `4.0.3`).
- `RTS_DIR = artifact"rts"/RTS-GMLC-0.2.3`.
- Builders read CSV/HDF5 time series and `.jl` data scripts out of these dirs. `src/utils/download.jl` additionally provides an OS-dispatched `Downloads.download(repo, branch, folder)` for descriptors with a `download_function` (most have none).

## SHARED-STATE / SERIALIZATION GOTCHA (platform-wide)

PSB **does not keep an in-memory system cache**; it caches **on disk** as serialized PSY JSON. This is the cross-test contamination surface.

- After a first build, `build_system` writes the `System` to `data/serialized_system/<hash>/<name>.json` (plus `_metadata.json`, `_validation_descriptors.json`, `_time_series_storage.h5`). `<hash>` is `SHA.sha256` of the case-arg string (`get_serialization_dir`), so different case kwargs get different cache dirs; a `case_parameters.json` records the args behind each hash.
- Subsequent calls **deserialize from that file** instead of rebuilding (`is_serialized` → `PSY.System(file_path; assign_new_uuids, sys_args...)`). Rebuild is forced when: `force_build=true`, any `SYSTEM_KWARGS` are passed (lambdas etc. can't be hashed into a path), the file is absent, or `skip_serialization` semantics apply.
- **`assign_new_uuids=true` is the default and matters**: each deserialized `System` and its components get fresh UUIDs, so two `build_system` calls return independent objects. Do **not** set `assign_new_uuids=false` in a shared test run unless you specifically need stable UUIDs — duplicate UUIDs across systems collide in IS containers.
- **Mutation contaminates only if you reuse the same object.** Each `build_system` call returns a distinct deserialized `System`, so a testset that mutates one build does not affect a later `build_system` call. But if you bind one system once and share it across testsets, mutations carry over — rebuild (or `deepcopy`) per testset that mutates. (Per user pref: do **not** `deepcopy` before a read-only call like `solve_power_flow`.)
- **Stale serialized cache** is the classic failure: after changing a builder or the underlying artifact, old JSON in `data/serialized_system/` is reused and your change appears to "not take". Clear it: `clear_serialized_system(name[, case_args])`, `clear_serialized_systems(name)`, or `clear_all_serialized_systems()` (all in `src/utils/utils.jl`), or pass `force_build=true`.
- Builds always end with `PSY.set_units_base_system!(sys, "SYSTEM_BASE")` — expect SYSTEM_BASE units regardless of how the case was authored.

The **`sienna-test-environment` skill** documents PSB usage inside other packages' test suites (the `--project=test` rule, isolation-vs-runtests failures, and these shared-state gotchas) — consult it when a downstream test passes alone but fails in `runtests.jl`.

## Conventions / gotchas

- `SystemDescriptor` and `SystemBuildStats` are `mutable struct`s with `set_*!`/`get_*` accessors — use the accessors, not dot access, in any user-facing code.
- Include order (module file): `definitions.jl` → `system_library.jl` → stats/descriptor/catalog → `utils/` → `build_system.jl` → `system_descriptor_data.jl` (which builds `SYSTEM_CATALOG` last, after all builders are defined). New constants must precede their use.
- PrettyTables printing is version-gated at load: `utils/print_pt_v2.jl` for PrettyTables v2, `utils/print_pt_v3.jl` for v3 (`compat = "2.4, 3.1"`).
- `SystemBuildStats` timing is currently mostly commented out in `_build_system` — treat the stats path as partly inert.

## Running tests, docs, formatter (verified commands)

Formatter (run before reporting any task done; self-activates its own env):

```sh
julia --project=scripts/formatter -e 'include("scripts/formatter/formatter_code.jl")'
```

Tests — runner is the classic `@includetests` macro (a vendored TestSetExtensions copy) in `test/runtests.jl`; it scans `test/` for `test_*.jl` files, and `ARGS` selects a subset by base name (no `.jl`):

```sh
julia --project=test test/runtests.jl                       # full suite
julia --project=test test/runtests.jl test_psisystems       # single file (no .jl extension)
julia --project=test -e 'using Pkg; Pkg.instantiate()'      # instantiate test env
```

Test files: `test_parsingtestsystems`, `test_psidtestsystems`, `test_psisystems`, `test_psitestsystems`, `test_psytestsystems`, `test_spisystems`, `test_system_catalog`, `test_unit_system`, `test_utils`.

Docs (Documenter + DocumenterInterLinks; `docs/make.jl` generates the catalog reference at build time):

```sh
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'   # first time
julia --project=docs docs/make.jl                                                              # must finish without errors
```
