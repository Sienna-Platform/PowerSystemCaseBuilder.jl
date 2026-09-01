function verify_storage_dir(folder::AbstractString = SERIALIZED_DIR)
    directory = abspath(normpath(folder))
    if !isdir(directory)
        mkpath(directory)
    end
end

function check_serialized_storage()
    verify_storage_dir(SERIALIZED_DIR)
    return
end

function clear_serialized_systems(name::String)
    for dir in _get_system_directories(SERIALIZED_DIR)
        bundle = joinpath(dir, name)
        if isdir(bundle)
            @debug "Deleting serialized system bundle" bundle
            rm(bundle; recursive = true, force = true)
        end
    end
    return
end

"""
Delete all files and references associated with a [`PowerSystems.System`](@extref) that has been serialized

Useful while debugging adding a new `System` to `PowerSystemCaseBuilder.jl`
to ensure all data and references are removed and that the new build is clean
"""
function clear_serialized_system(
    name::String,
    case_args::Dict{Symbol, <:Any} = Dict{Symbol, Any}(),
)
    dir_path = get_serialized_dirpath(name, case_args)
    if isdir(dir_path)
        @debug "Deleting serialized system bundle at " dir_path
        rm(dir_path; recursive = true, force = true)
    end

    return
end

"""
Delete all data and files for [`PowerSystems.System`](@extref)s that have been serialized
"""
function clear_all_serialized_systems(path::String)
    for path in _get_system_directories(path)
        rm(path; recursive = true)
    end
end

clear_all_serialized_systems() = clear_all_serialized_systems(SERIALIZED_DIR)
clear_all_serialized_system() = clear_all_serialized_systems()

function get_serialization_dir(case_args::Dict{Symbol, <:Any} = Dict{Symbol, Any}())
    args_string = join(["$key=$value" for (key, value) in case_args], "_")
    hash_value = bytes2hex(SHA.sha256(args_string))
    return joinpath(PACKAGE_DIR, "data", "serialized_system", "$hash_value")
end

"""
Directory holding one cached `System`, written by `PSY.to_file` and read by `PSY.from_file`.

A serialized `System` is a bundle directory (`system.json` + `time_series.h5`), not a single
file, so a cache entry is a directory named after the system rather than `<name>.json` plus
sibling files sharing its stem.
"""
function get_serialized_dirpath(
    name::String,
    case_args::Dict{Symbol, <:Any} = Dict{Symbol, Any}(),
)
    dir = get_serialization_dir(case_args)
    return joinpath(dir, name)
end

"""
Whether `name` has a complete cache entry.

Checks for the document rather than just the directory: a directory left behind by an
interrupted write would otherwise look like a valid cache entry and fail confusingly on read.
"""
function is_serialized(name::String, case_args::Dict{Symbol, <:Any} = Dict{Symbol, Any}())
    return isfile(
        joinpath(get_serialized_dirpath(name, case_args), PSY.SYSTEM_DOCUMENT_FILE),
    )
end

function get_raw_data(; kwargs...)
    if haskey(kwargs, :raw_data)
        return kwargs[:raw_data]
    else
        throw(ArgumentError("Raw data directory not passed in build function."))
    end
end

function filter_kwargs(; kwargs...)
    system_kwargs = filter(x -> in(first(x), PSY.SYSTEM_KWARGS), kwargs)
    return system_kwargs
end

"""
Creates a JSON file informing the user about the meaning of the hash value in the file path
if it doesn't exist already
"""
function serialize_case_parameters(case_args::Dict{Symbol, <:Any})
    dir_path = get_serialization_dir(case_args)
    file_path = joinpath(dir_path, "case_parameters.json")

    if !isfile(file_path)
        open(file_path, "w") do io
            JSON.print(io, case_args)
        end
    end
end

function _get_system_directories(path::String)
    return (
        joinpath(path, x) for
        x in readdir(path) if isdir(joinpath(path, x)) && _is_system_hash_name(x)
    )
end

_is_system_hash_name(name::String) = isempty(filter(!isxdigit, name)) && length(name) == 64

function convert_to_hydropump!(d::EnergyReservoirStorage, sys::System)
    storage_capacity_MWh = d.storage_capacity * d.base_power
    reservoir_cost = HydroReservoirCost(;
        level_shortage_cost = d.operation_cost.energy_shortage_cost,
        level_surplus_cost = d.operation_cost.energy_surplus_cost,
        spillage_cost = 0.0,
    )
    hpump = HydroPumpTurbine(;
        name = "$(d.name)_pump",
        available = d.available,
        bus = d.bus,
        active_power = d.active_power,
        reactive_power = d.reactive_power,
        rating = d.rating,
        active_power_limits = d.output_active_power_limits,
        reactive_power_limits = d.reactive_power_limits,
        active_power_limits_pump = d.input_active_power_limits,
        outflow_limits = nothing,
        powerhouse_elevation = 0.0,
        ramp_limits = nothing,
        time_limits = nothing,
        base_power = d.base_power,
        operation_cost = HydroGenerationCost(;
            variable_operation_cost = d.operation_cost.discharge_variable_cost,
            fixed = d.operation_cost.fixed,
        ),
        active_power_pump = 0.0,
        efficiency = (turbine = d.efficiency.out, pump = d.efficiency.in),
        must_run = false,
    )
    head_reservoir = HydroReservoir(;
        name = "$(d.name)_head_reservoir",
        available = d.available,
        storage_level_limits = (
            min = storage_capacity_MWh * d.storage_level_limits.min,
            max = storage_capacity_MWh * d.storage_level_limits.max,
        ),
        initial_level = d.initial_storage_capacity_level,
        spillage_limits = nothing,
        inflow = 1.0,
        outflow = 0.0,
        level_targets = d.storage_target,
        intake_elevation = 0.0,
        head_to_volume_factor = LinearFunctionData(0.0),
        operation_cost = reservoir_cost,
        level_data_type = ReservoirDataType.ENERGY,
    )
    tail_reservoir = HydroReservoir(nothing)
    PSY.set_name!(tail_reservoir, "$(d.name)_tail_reservoir")
    PSY.set_available!(tail_reservoir, d.available)
    PSY.set_storage_level_limits!(tail_reservoir, (min = 0.0, max = 1.0e9))
    PSY.set_initial_level!(tail_reservoir, 0.0)
    add_component!(sys, hpump)
    add_component!(sys, head_reservoir)
    add_component!(sys, tail_reservoir)
    set_downstream_turbines!(head_reservoir, [hpump])
    set_upstream_turbines!(tail_reservoir, [hpump])
    set_upstream_reservoirs!(tail_reservoir, [head_reservoir])
    for service in PSY.get_services(d)
        PSY.add_service!(hpump, service, sys)
    end
    copy_time_series!(hpump, d)
end
