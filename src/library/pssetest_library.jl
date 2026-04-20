function build_psse_RTS_GMLC_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = make_system(PowerFlowFileParser.PowerModelsData(raw_data), sys_kwargs...)

    return sys
end

function build_psse_ACTIVSg2000_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "ACTIVSg2000", "ACTIVSg2000.RAW")
    dyr_file = joinpath(raw_data, "psse_dyr", "ACTIVSg2000_dynamics.dyr")
    sys = make_system(PowerFlowFileParser.PowerModelsData(file_path), sys_kwargs...)
    add_dyn_injectors!(sys, dyr_file)
    return sys
end

function build_pti(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = make_system(PowerFlowFileParser.PowerModelsData(raw_data), sys_kwargs...)
    return sys
end

function build_pti_30(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = make_system(PowerFlowFileParser.PowerFlowDataNetwork(raw_data), sys_kwargs...)
    return sys
end
