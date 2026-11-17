# Known, verified defects in the RTS-GMLC test-data artifact (external,
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
"""
const KNOWN_STALE_TIME_SERIES_ROWS = Set([
    ("Component", "201_HYDRO_4_RESERVOIR_head"),
])

"""
Reservoir series filed under a generator that has no reservoir, as (category, component,
series name). PowerTableDataParser moves a reservoir-normalized series off a turbine onto the
reservoir feeding it; a `HydroDispatch` has none, so the parser rejects the row. Unlike
[`KNOWN_STALE_TIME_SERIES_ROWS`](@ref), the component's other series are kept.

PowerSystemsTestData-5.0-dev13: `201_HYDRO_4` (RTS_GMLC/timeseries_pointers.json, the
run-of-river unit above).
"""
const KNOWN_RESERVOIR_SERIES_WITHOUT_RESERVOIR = Set([
    ("Generator", "201_HYDRO_4", "inflow"),
    ("Generator", "201_HYDRO_4", "storage_capacity"),
])

"""
Return `rawsys` unchanged if it carries no time-series pointer file, or its
`timeseries_metadata_file` matches nothing in [`KNOWN_STALE_TIME_SERIES_ROWS`](@ref) or
[`KNOWN_RESERVOIR_SERIES_WITHOUT_RESERVOIR`](@ref). Otherwise return a copy pointing at a
fixed temp copy of the pointer file, with the known-dangling rows dropped.
"""
function fix_known_stale_time_series_data(
    rawsys::PowerTableDataParser.PowerSystemTableData,
)
    path = rawsys.timeseries_metadata_file
    if isnothing(path)
        return rawsys
    end
    rows = JSON.parsefile(path)
    fixed = [
        row for row in rows if
        (row["category"], row["component_name"]) ∉ KNOWN_STALE_TIME_SERIES_ROWS &&
        (row["category"], row["component_name"], row["name"]) ∉
        KNOWN_RESERVOIR_SERIES_WITHOUT_RESERVOIR
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

"""
Matpower fixture data that no Sienna type represents, and that PowerFlowFileParser's
OpenAPI builder therefore rejects rather than skips. Matched exactly so any new data of
either kind still errors.

`ne_branch` (case3_tnep.m, case5_tnep.m): PowerModels' transmission-expansion candidate
branches.

`313_STORAGE_1` (RTS_GMLC.m, gen row 158): a storage unit listed as a generator. Matpower
storage belongs in its own `storage` table, which this case does not have.
"""
const KNOWN_UNREAD_MATPOWER_SECTIONS = ("ne_branch",)
const KNOWN_STORAGE_GENERATOR_ROWS = Set(["313_STORAGE_1"])

function drop_known_unread_matpower_data!(pm_data::PowerFlowFileParser.PowerModelsData)
    data = pm_data.data
    for section in KNOWN_UNREAD_MATPOWER_SECTIONS
        delete!(data, section)
    end
    filter!(p -> get(last(p), "name", nothing) ∉ KNOWN_STORAGE_GENERATOR_ROWS, data["gen"])
    return pm_data
end
