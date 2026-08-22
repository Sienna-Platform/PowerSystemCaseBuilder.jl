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
to hand them over in memory: `from_openapi` takes a `time_series_storage_path` and adopts
the store it opens from it (`_system_with_sidecar`), so accepting an already-open store
would be what removes the round trip. And PSY's importer expects the round-tripped shape of
some values regardless of time series; see the note on the PSS/E method.

`to_json` writes the sidecar beside the document and `from_file` resolves it back off the
document, so neither path is spelled out here. The bundle is scoped to the call: the
adopted store is a working copy, so a bare `mktempdir` would just hold a dead original
until the process exits.
"""
function system_from_document(oapi; kwargs...)
    return mktempdir() do dir
        _write_document(oapi, joinpath(dir, PowerSystems.SYSTEM_DOCUMENT_FILE))
        PowerSystems.from_file(PowerSystems.System, dir; kwargs...)
    end
end

"""
Build a `System` from table data. `time_series_resolution` keeps only the series at that
resolution, matching the retired `make_system`'s kwarg of the same name; the filter is
applied to the parser's staged series, before the sidecar is written, because the sidecar's
catalog — not the document's association rows — is what PowerSystems reads the series back
through.
"""
function system_from_openapi(
    rawsys::PowerTableDataParser.PowerSystemTableData;
    time_series_resolution::Union{Dates.Period, Nothing} = nothing,
    kwargs...,
)
    oapi = PowerTableDataParser.build_openapi_system(
        fix_known_stale_time_series_data(rawsys),
    )
    PowerTableDataParser.keep_time_series_resolution!(oapi, time_series_resolution)
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
