function build_matpower(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    pm_data = PowerFlowFileParser.PowerModelsData(raw_data)
    sys = system_from_openapi(drop_known_unread_matpower_data!(pm_data); sys_kwargs...)
    return sys
end
