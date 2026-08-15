# Replaces the retired power_system_table_data.jl (make_system + its *_csv_parser!
# functions): table data now flows through the OpenAPI document pipeline —
# PowerTableDataParser.build_openapi_system -> JSON document + HDF5 sidecar ->
# PowerSystems.from_openapi(System, doc) — verified end to end against the full RTS
# corpus (.claude/plans/2026-08-04-pscb-openapi-pipeline-switchover.md, Phases 1-2).

"""
Build a `System` from `rawsys` through the OpenAPI document pipeline, replacing the
retired `make_system(rawsys::PowerSystemTableData)`.

`time_series_resolution` filters the document's `time_series_associations` to just the
matching resolution before import — the old path's `add_time_series!(...;
resolution = ...)` kwarg applied the same `metadata.resolution == resolution` equality
filter (`IS.add_time_series_from_file_metadata!`); `nothing` (the default) keeps every
resolution, matching the old default too.

Every other `kwargs` entry passes straight through to
`PSY.from_openapi(System, doc; system_kwargs...)`, which forwards it to `System`'s own
constructor (`time_series_in_memory`, `time_series_directory`, `time_series_read_only`,
`runchecks`, ... — `PSY.SYSTEM_KWARGS`); an unsupported key still errors, from `System`'s
own constructor, not here.
"""
function system_from_openapi(
    rawsys::PowerTableDataParser.PowerSystemTableData;
    time_series_resolution::Union{Dates.Period, Nothing} = nothing,
    kwargs...,
)
    rawsys = fix_known_stale_time_series_data(rawsys)
    oapi = PowerTableDataParser.build_openapi_system(rawsys)
    dir = mktempdir()
    doc_path = joinpath(dir, "system.json")
    PowerTableDataParser.to_json(oapi, doc_path; force = true, pretty = false)
    ts_path = joinpath(dir, "system_time_series_storage.h5")
    PowerTableDataParser.write_time_series(oapi, ts_path)

    # Reached through PowerSystems rather than by depending on PowerCoreOpenAPIModels
    # directly: PSCB is being trimmed to PSY + the parsers, so this avoids a new dep for one
    # call. Revisit when PSCB's dependency set is settled.
    doc = PowerSystems.PC.read_document(doc_path)
    _filter_time_series_resolution!(doc, time_series_resolution)

    sys = PowerSystems.from_openapi(
        PowerSystems.System,
        doc;
        time_series_storage_path = ts_path,
        kwargs...,
    )
    check(sys)
    return sys
end

"""
Build a `System` from PSS/E or Matpower data through the OpenAPI document pipeline,
replacing `make_system(pm_data::PowerFlowFileParser.PowerModelsData)`.

Unlike the table-data path there is no serialization step: `build_openapi_system` returns
the `SystemDocument` already, and these formats carry no time series, so there is no
sidecar to write and nothing for `from_openapi` to read back.

`kwargs` are split the way the retired `make_system` split them — the `*_name_formatter`
entries go to the reader, everything else to `System`'s own constructor.
"""
function system_from_openapi(
    pm_data::PowerFlowFileParser.PowerModelsData;
    kwargs...,
)
    reader_kwargs = filter(p -> endswith(string(first(p)), "_name_formatter"), kwargs)
    system_kwargs = filter(p -> !endswith(string(first(p)), "_name_formatter"), kwargs)
    oapi = PowerFlowFileParser.build_openapi_system(pm_data; reader_kwargs...)
    sys = PowerSystems.from_openapi(
        PowerSystems.System,
        PowerFlowFileParser.get_document(oapi);
        system_kwargs...,
    )
    check(sys)
    return sys
end

_filter_time_series_resolution!(doc, ::Nothing) = doc

"""Keep only `time_series_associations` rows whose ISO 8601 `PT<seconds>S` resolution
(the only form PowerTableDataParser's writer emits) matches `resolution`, mirroring
`IS.add_time_series_from_file_metadata!`'s `metadata.resolution == resolution` filter."""
function _filter_time_series_resolution!(doc, resolution::Dates.Period)
    target = "PT$(Dates.value(Dates.Second(resolution)))S"
    filter!(row -> row.resolution == target, doc.time_series_associations)
    return doc
end
