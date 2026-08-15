# Known, verified defects in the RTS-GMLC and 5-Bus test-data artifacts (external,
# version-pinned via Artifacts.toml — not owned by this repo; fixing them at the source
# needs a new artifact release, out of reach here).
#
# The retired power_system_table_data.jl path tolerated dangling references silently: IS's
# `set_component!` (system_data.jl) does `@warn` and sets the association's component to
# `nothing` on a zero-match lookup, and PSY's `add_time_series_from_file_metadata_internal!`
# then drops that row without complaint. The new pipeline errors instead — psy6's
# no-silent-skip policy correctly surfacing defects the old parser was quietly hiding. Each
# is filtered/remapped explicitly here, by exact match, before `build_openapi_system` reads
# the pointer file — a reviewed, narrow exception at this one call site, not a change to
# PowerTableDataParser's or PowerSystems' own strict behavior.

"""
Confirmed dangling time-series pointer rows: the referenced component genuinely does not
exist anywhere in that dataset's own csv tables.

RTS-GMLC-0.2.3 (`rts` artifact, RTS_SIIP_DIR/timeseries_pointers.json): 201_HYDRO_4 is a
run-of-river unit (gen.csv: Unit Type = ROR) and, unlike every other *_HYDRO_* unit, has no
storage.csv row — by design it has no HydroReservoir — yet the pointer file still names
"201_HYDRO_4_RESERVOIR_head" for its inflow/storage_target series.

PowerSystemsTestData-5.0-dev4 5-Bus dataset (CaseData artifact, 5bus_ts/7day/*.json): the
pointer files were evidently authored against a richer template (real solar/wind
generators, 4 reserves) than this snapshot's gen.csv (no renewables) / reserves.csv
(REG1 only) actually contains.
"""
const KNOWN_STALE_TIME_SERIES_ROWS = Set([
    ("Component", "201_HYDRO_4_RESERVOIR_head"),
    ("Generator", "SolarBusC"),
    ("Generator", "WindBusA"),
    ("Reserve", "REG2"),
    ("Reserve", "REG3"),
    ("Reserve", "REG4"),
])

"""
Confirmed stale `scaling_factor_multiplier` names: a getter that exists in PSY but not on
the component type the pointer row applies it to.

`"get_storage_target"` (PowerSystemsTestData-5.0-dev4 5-Bus dataset,
5bus_ts/7day/*.json): a real PSY getter, but only on `EnergyReservoirStorage` — every
occurrence in these pointer files names a `HydroReservoir` (`HydroReservoir1_head`,
`HydroReservoir2_head`), whose equivalent end-of-simulation target field is
`level_targets`, i.e. `get_level_targets`.
"""
const KNOWN_STALE_SCALING_FACTOR_MULTIPLIERS = Dict(
    "get_storage_target" => "get_level_targets",
)

"""
Return `rawsys` unchanged if it carries no time-series pointer file, or its
`timeseries_metadata_file` matches nothing in [`KNOWN_STALE_TIME_SERIES_ROWS`](@ref) or
[`KNOWN_STALE_SCALING_FACTOR_MULTIPLIERS`](@ref). Otherwise return a copy pointing at a
fixed temp copy of the pointer file: known-dangling rows dropped, known-stale multiplier
names remapped.
"""
function fix_known_stale_time_series_data(
    rawsys::PowerTableDataParser.PowerSystemTableData,
)
    path = rawsys.timeseries_metadata_file
    if isnothing(path)
        return rawsys
    end
    rows = JSON.parsefile(path)
    kept = [
        row for row in rows if
        (row["category"], row["component_name"]) ∉ KNOWN_STALE_TIME_SERIES_ROWS
    ]
    fixed = [
        if haskey(row, "scaling_factor_multiplier") &&
           haskey(KNOWN_STALE_SCALING_FACTOR_MULTIPLIERS, row["scaling_factor_multiplier"])
            merge(
                row,
                Dict(
                    "scaling_factor_multiplier" =>
                        KNOWN_STALE_SCALING_FACTOR_MULTIPLIERS[row["scaling_factor_multiplier"]],
                ),
            )
        else
            row
        end for row in kept
    ]
    if fixed == rows
        return rawsys
    end
    # Each row's `data_file` is relative to the ORIGINAL pointer file's directory
    # (PowerTableDataParser resolves it via `abspath(joinpath(dirname(metadata_file),
    # row["data_file"]))`); the fixed copy lives elsewhere, so re-root every path to
    # absolute before writing it out, or the relative paths break.
    original_dir = dirname(path)
    fixed = [
        merge(row, Dict("data_file" => abspath(joinpath(original_dir, row["data_file"]))))
        for row in fixed
    ]
    fixed_path = joinpath(mktempdir(), basename(path))
    open(fixed_path, "w") do io
        JSON.print(io, fixed)
    end
    return _with_timeseries_metadata_file(rawsys, fixed_path)
end

"""
Copy `rawsys` with `timeseries_metadata_file` replaced.

Field values are taken by name rather than positionally: `PowerSystemTableData` belongs to
PowerTableDataParser, and two of its seven fields are adjacent `Dict`s, so a reorder there
would leave a positional rebuild compiling and silently wrong.
"""
function _with_timeseries_metadata_file(
    rawsys::PowerTableDataParser.PowerSystemTableData,
    path::AbstractString,
)
    T = PowerTableDataParser.PowerSystemTableData
    values = map(fieldnames(T)) do field
        if field === :timeseries_metadata_file
            return path
        end
        return getfield(rawsys, field)
    end
    return T(values...)
end
