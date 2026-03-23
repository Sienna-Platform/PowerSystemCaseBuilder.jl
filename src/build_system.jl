"""
Builds a [`PowerSystems.System`](@extref) from one of the predefined categories of test
systems

# Arguments
- `category::Type{<:SystemCategory}`: A subtype of [`SystemCategory`](@ref)
- `name::String`: Name of the `System` to build

# Accepted Key Words
- `print_stat::Bool = false`: Print statistics about the system build process
- `force_build::Bool`: `true` runs entire build process, `false` (Default) uses deserializiation if possible
- `assign_new_uuids::Bool`: Assign new UUIDs to the system and all components if
   deserialization is used. Default is `true`.
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
        serialized_filepath = get_serialized_filepath(name, case_args)
        start = time()
        if !skip_serialization && isempty(sys_args)
            PSY.to_json(sys, serialized_filepath; force = true)
            #serialize_time = time() - start
            serialize_case_parameters(case_args)
        end
        # set_stats!(sys_descriptor, SystemBuildStats(construct_time, serialize_time))
    else
        @debug "Deserialize system from file" sys_descriptor.name
        start = time()
        # time_series_in_memory = get(kwargs, :time_series_in_memory, false)
        file_path = get_serialized_filepath(name, case_args)
        sys = PSY.System(file_path; assign_new_uuids = assign_new_uuids, sys_args...)
        PSY.get_runchecks(sys)
        # update_stats!(sys_descriptor, time() - start)
    end
    PSY.set_units_base_system!(sys, "SYSTEM_BASE")
    print_stat ? print_stats(sys_descriptor) : nothing
    return sys
end
