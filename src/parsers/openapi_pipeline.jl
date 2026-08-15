# Glue only. The parsers emit an OpenAPI document, PowerSystems reads one; this package is
# just the one that depends on both sides, since neither parser can depend on PowerSystems
# nor PowerSystems on a parser.

# The two parsers' `to_json` are distinct functions, so the write dispatches. Everything
# after it is shared.
_write_document(oapi::PowerTableDataParser.OpenAPISystem, path::AbstractString) =
    PowerTableDataParser.to_json(oapi, path; force = true)

_write_document(oapi::PowerFlowFileParser.OpenAPISystem, path::AbstractString) =
    PowerFlowFileParser.to_json(oapi, path; force = true)

"""
Load a parser's OpenAPI document into a `System`, via a temporary bundle on disk.

Two reasons the bundle is not skippable today. A document carrying time series has nowhere
to hand them over in memory: `from_openapi` reads series through an
`IS.Hdf5TimeSeriesStorage` built from a path (`sqlite_load.jl`), so widening those readers
to `IS.TimeSeriesStorage` — `InMemoryTimeSeriesStorage` already implements the same
interface — is what would remove it. And PSY's importer expects the round-tripped shape of
some values regardless of time series; see the note on the PSS/E method.

`to_json` writes the sidecar beside the document and `from_file` resolves it back off the
document, so neither path is spelled out here. The bundle is scoped to the call:
`from_file` materializes every series into the `System`'s own storage, so a bare
`mktempdir` would just hold a dead copy until the process exits.
"""
function system_from_document(oapi; kwargs...)
    return mktempdir() do dir
        _write_document(oapi, joinpath(dir, PowerSystems.SYSTEM_DOCUMENT_FILE))
        PowerSystems.from_file(PowerSystems.System, dir; kwargs...)
    end
end

"""
Build a `System` from table data. `time_series_resolution` keeps only the associations at
that resolution, matching the retired `make_system`'s kwarg of the same name.
"""
function system_from_openapi(
    rawsys::PowerTableDataParser.PowerSystemTableData;
    time_series_resolution::Union{Dates.Period, Nothing} = nothing,
    kwargs...,
)
    oapi = PowerTableDataParser.build_openapi_system(
        fix_known_stale_time_series_data(rawsys),
    )
    _keep_time_series_resolution!(oapi, time_series_resolution)
    return system_from_document(oapi; kwargs...)
end

"""
Build a `System` from PSS/E or Matpower data.

Goes through the document on disk even though these formats carry no time series and
`from_openapi` would accept the in-memory document directly. Handing it over in memory
errors on an LCC line: `_hvdc_loss_curve` (PSY `import_handwritten.jl`) reads a `value`
field off the loss curve's function data, which only exists after a JSON round trip
normalizes it — PSY's importer is written against the round-tripped shape. Take the
shortcut once that is fixed, not before.
"""
function system_from_openapi(pm_data::PowerFlowFileParser.PowerModelsData; kwargs...)
    oapi = PowerFlowFileParser.build_openapi_system(pm_data; kwargs...)
    return system_from_document(oapi; filter_kwargs(; kwargs...)...)
end

"""
Drop every time series whose resolution is not `resolution`, before the sidecar is written.

Errors when nothing matches: the association's `resolution` is a wire string, so a
mismatch between the requested `Period` and the encoding the writer emits would otherwise
yield a `System` with silently no time series.
"""
function _keep_time_series_resolution!(oapi, resolution::Dates.Period)
    target = "PT$(Dates.value(Dates.Second(resolution)))S"
    associations = PowerTableDataParser.get_time_series_associations(oapi)
    if !any(row -> row.resolution == target, associations)
        throw(
            IS.DataFormatError(
                "no time series at resolution $resolution (looked for $target); " *
                "the document carries $(unique(row.resolution for row in associations))",
            ),
        )
    end
    filter!(row -> row.resolution == target, associations)
    return
end

function _keep_time_series_resolution!(oapi, ::Nothing)
    return
end
