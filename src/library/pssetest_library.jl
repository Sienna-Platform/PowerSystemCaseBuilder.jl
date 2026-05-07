function build_psse_RTS_GMLC_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = PSY.System(PSY.PowerModelsData(raw_data), sys_kwargs...)

    return sys
end

function build_psse_ACTIVSg2000_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "ACTIVSg2000", "ACTIVSg2000.RAW")
    dyr_file = joinpath(raw_data, "psse_dyr", "ACTIVSg2000_dynamics.dyr")
    sys = PSY.System(file_path, dyr_file; sys_kwargs...)

    return sys
end

function build_pti(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = PSY.System(PSY.PowerModelsData(raw_data), sys_kwargs...)
    return sys
end

function build_pti_30(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = PSY.System(PSY.PowerFlowDataNetwork(raw_data), sys_kwargs...)
    return sys
end

function build_psse_modified_14bus_sys(; raw_data, kwargs...)
    sys = PSY.System(raw_data; runchecks = false)
    # The RAW file defines two type-3 (REF) buses in the same island;
    # demote bus 108 to PV so there is exactly one reference bus per subnetwork.
    PSY.set_bustype!(PSY.get_component(PSY.ACBus, sys, "BUS 108"), PSY.ACBusTypes.PV)
    return sys
end
