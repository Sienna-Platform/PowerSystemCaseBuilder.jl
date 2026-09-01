"""
Builds a [`PowerSystems.System`](@extref) from one of the predefined categories of test
systems

# Arguments
- `category::Type{<:SystemCategory}`: A subtype of [`SystemCategory`](@ref)
- `name::String`: Name of the `System` to build

# Accepted Key Words
- `print_stat::Bool = false`: Print statistics about the system build process
- `force_build::Bool`: `true` runs entire build process, `false` (Default) uses deserializiation if possible
- `assign_new_uuids::Bool`: Retained for signature compatibility and effectively always
   `true`. A cached `System` is read from an OpenAPI document, which carries component ids
   rather than UUIDs, so every load rebuilds components with fresh UUIDs and there is nothing
   to reassign. Passing `false` warns, since stable UUIDs across loads can no longer be
   delivered.
- `skip_serialization::Bool`: Default is `false`
- `system_catalog::SystemCatalog`: Defaults to the `PowerSystemCaseBuilder.jl` catalog of `System`s
"""
function build_system(
    category::Type{<:SystemCategory},
    name::String,
    print_stat::Bool = false;
    force_build::Bool = false,
    assign_new_uuids::Bool = true,
    skip_serialization::Bool = false,
    system_catalog::SystemCatalog = SystemCatalog(SYSTEM_CATALOG),
    kwargs...,
)
    sys_descriptor = get_system_descriptor(category, system_catalog, name)
    sys_kwargs = filter_kwargs(; kwargs...)
    case_kwargs = filter_descriptor_kwargs(sys_descriptor; kwargs...)
    if length(kwargs) > length(sys_kwargs) + length(case_kwargs)
        unexpected = setdiff(keys(kwargs), union(keys(sys_kwargs), keys(case_kwargs)))
        error("These keyword arguments are not supported: $unexpected")
    end

    duplicates = intersect(keys(sys_kwargs), keys(case_kwargs))
    if !isempty(duplicates)
        error("System kwargs and case kwargs have overlapping keys: $duplicates")
    end

    return _build_system(
        name,
        sys_descriptor,
        case_kwargs,
        sys_kwargs,
        print_stat;
        force_build,
        assign_new_uuids,
        skip_serialization,
    )
end

"""
Whether `sys` can round-trip through an OpenAPI document without loss.

Forecasts round-trip as of PSY converter-plan §4 (Deterministic, DeterministicSingleTimeSeries,
SingleTimeSeries — Probabilistic/Scenarios still do not, see PSY's
`_missing_structural_field`, but no PSCB builder produces either), so that clause is gone.
What remains: any component whose type PSY's document converters do not cover at all —
dynamics today — per PSY's own `is_document_exportable` trait (`src/openapi/ledger.jl`,
generated from `DOCUMENT_PLAN`). Caching such a system anyway would silently truncate it on
the next load (a dynamics-carrying system reads back with none — the exact trap this
function exists to prevent).
"""
function _is_losslessly_serializable(sys::PSY.System, name::AbstractString)
    unexportable = Dict{String, Int}()
    for component in PSY.get_components(PSY.Component, sys)
        PSY.is_document_exportable(component) && continue
        type_name = string(nameof(typeof(component)))
        unexportable[type_name] = get(unexportable, type_name, 0) + 1
    end
    if !isempty(unexportable)
        listed = join(
            ("$k ($(unexportable[k]))" for k in sort(collect(keys(unexportable)))), ", ",
        )
        @info "Not caching $name: it carries component type(s) with no OpenAPI document " *
              "converter ($listed), which would be silently dropped by a cached round trip. " *
              "It will be rebuilt from raw data each time."
        return false
    end
    return true
end

function _build_system(
    name::String,
    sys_descriptor::SystemDescriptor,
    case_args::Dict{Symbol, <:Any},
    sys_args::Dict{Symbol, <:Any},
    print_stat::Bool = false;
    force_build::Bool = false,
    assign_new_uuids::Bool = true,
    skip_serialization::Bool = false,
)
    # We skip serialization/de-serialization if sys_args are passed because we currently
    # cannot encode information about some of them into file paths
    # (such as lambda functions).
    if !isempty(sys_args) || !is_serialized(name, case_args) || force_build
        check_serialized_storage()
        download_function = get_download_function(sys_descriptor)
        if !isnothing(download_function)
            filepath = download_function()
            set_raw_data!(sys_descriptor, filepath)
        end
        @info "Building new system $(sys_descriptor.name) from raw data" sys_descriptor.raw_data
        build_func = get_build_function(sys_descriptor)
        start = time()
        sys = build_func(;
            raw_data = sys_descriptor.raw_data,
            case_args...,
            sys_args...,
        )
        #construct_time = time() - start
        start = time()
        if !skip_serialization && isempty(sys_args) &&
           _is_losslessly_serializable(sys, name)
            # Component base is what PSY stores internally, so the cache is a direct
            # write of stored values with no unit conversion.
            PSY.to_file(
                sys,
                get_serialized_dirpath(name, case_args);
                power_units = :component_base,
                force = true,
            )
            #serialize_time = time() - start
            serialize_case_parameters(case_args)
        end
        # set_stats!(sys_descriptor, SystemBuildStats(construct_time, serialize_time))
    else
        @debug "Deserialize system from bundle" sys_descriptor.name
        start = time()
        if !assign_new_uuids
            @warn "assign_new_uuids = false cannot be honored: a cached System is read from " *
                  "an OpenAPI document, which carries component ids rather than UUIDs, so " *
                  "every load rebuilds components with fresh UUIDs"
        end
        sys =
            PSY.from_file(PSY.System, get_serialized_dirpath(name, case_args); sys_args...)
        PSY.get_runchecks(sys)
        # update_stats!(sys_descriptor, time() - start)
    end
    print_stat ? print_stats(sys_descriptor) : nothing
    return sys
end
