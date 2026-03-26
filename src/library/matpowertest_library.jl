function build_matpower(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = PSY.System(PowerFlowFileParser.PowerModelsData(raw_data); sys_kwargs...)
    return sys
end
