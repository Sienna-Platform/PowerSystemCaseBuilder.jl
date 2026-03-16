function _get_generic_hydro_reservoir_pair(node)
    reservoir = PSY.HydroReservoir(;
        name = "HydroReservoir",
        available = true,
        storage_level_limits = (min = 0.0, max = 50.0),
        spillage_limits = nothing,
        inflow = 4.0,
        outflow = 0.0,
        level_targets = nothing,
        intake_elevation = 0.0,
        initial_level = 0.5,
        head_to_volume_factor = LinearCurve(0.0),
        operation_cost = HydroReservoirCost(),
    )

    hydro = HydroTurbine(;
        name = "HydroEnergyReservoirTurbine",
        available = true,
        bus = node,
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 7.0,
        active_power_limits = (min = 0.0, max = 7.0),
        reactive_power_limits = (min = 0.0, max = 7.0),
        ramp_limits = (up = 7.0, down = 7.0),
        time_limits = nothing,
        operation_cost = HydroGenerationCost(
            CostCurve(LinearCurve(0.15)), 0.0),
        base_power = 100.0,
        travel_time = 0.0,
        conversion_factor = 1.0,
        outflow_limits = nothing,
        powerhouse_elevation = 0.0,
    )
    return hydro, reservoir
end

function build_c_sys14(; add_forecasts, add_single_time_series, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes14()
    c_sys14 = PSY.System(
        100.0,
        nodes,
        thermal_generators14(nodes),
        loads14(nodes),
        branches14(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
    for (ix, l) in enumerate(PSY.get_components(PowerLoad, c_sys14))
        for t in 1:2
            ini_time = TimeSeries.timestamp(timeseries_DA14[t][ix])[1]
            forecast_data[ini_time] = timeseries_DA14[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys14,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    single_timeseries_DA14[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys14,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    return c_sys14
end

function build_c_sys14_dc(; add_forecasts, add_single_time_series, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes14()
    c_sys14_dc = PSY.System(
        100.0,
        nodes,
        thermal_generators14(nodes),
        loads14(nodes),
        branches14_dc(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys14_dc))
        for t in 1:2
            ini_time = TimeSeries.timestamp(timeseries_DA14[t][ix])[1]
            forecast_data[ini_time] = timeseries_DA14[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys14_dc,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    single_timeseries_DA14[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys14_dc,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    return c_sys14_dc
end

function build_c_sys5(; add_forecasts, add_single_time_series, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5 = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PowerLoad, c_sys5))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            add_time_series!(
                c_sys5,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                add_time_series!(
                    c_sys5,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    return c_sys5
end

function build_c_sys5_ml(; add_forecasts, add_single_time_series, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_ml = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PowerLoad, c_sys5_ml))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            add_time_series!(
                c_sys5_ml,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                add_time_series!(
                    c_sys5_ml,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    line = PSY.get_component(Line, c_sys5_ml, "1")
    PSY.convert_component!(c_sys5_ml, line, MonitoredLine)
    return c_sys5_ml
end

function build_c_sys5_re(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    nodes = nodes5()
    c_sys5_re = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_re))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_re,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_re,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, r) in enumerate(PSY.get_components(RenewableGen, c_sys5_re))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(ren_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = ren_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_re,
                r,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_re,
                    r,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    if add_reserves
        reserve_re = reserve5_re(PSY.get_components(PSY.RenewableDispatch, c_sys5_re))
        PSY.add_service!(
            c_sys5_re,
            reserve_re[1],
            PSY.get_components(PSY.RenewableDispatch, c_sys5_re),
        )
        PSY.add_service!(
            c_sys5_re,
            reserve_re[2],
            [collect(PSY.get_components(PSY.RenewableDispatch, c_sys5_re))[end]],
        )
        # ORDC
        PSY.add_service!(
            c_sys5_re,
            reserve_re[3],
            PSY.get_components(PSY.RenewableDispatch, c_sys5_re),
        )
        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_re))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_re,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_re,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_re))
            PSY.set_variable_cost!(
                c_sys5_re,
                serv,
                ORDC_cost,
            )
        end
    end

    return c_sys5_re
end

function build_c_sys5_re_fuel_cost(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    nodes = nodes5()
    c_sys5_re = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_re))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_re,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_re,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, r) in enumerate(PSY.get_components(RenewableGen, c_sys5_re))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(ren_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = ren_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_re,
                r,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_re,
                    r,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    if add_reserves
        reserve_re = reserve5_re(PSY.get_components(PSY.RenewableDispatch, c_sys5_re))
        PSY.add_service!(
            c_sys5_re,
            reserve_re[1],
            PSY.get_components(PSY.RenewableDispatch, c_sys5_re),
        )
        PSY.add_service!(
            c_sys5_re,
            reserve_re[2],
            [collect(PSY.get_components(PSY.RenewableDispatch, c_sys5_re))[end]],
        )
        # ORDC
        PSY.add_service!(
            c_sys5_re,
            reserve_re[3],
            PSY.get_components(PSY.RenewableDispatch, c_sys5_re),
        )
        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_re))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_re,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_re,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_re))
            PSY.set_variable_cost!(
                c_sys5_re,
                serv,
                ORDC_cost,
            )
        end
    end
    ### Update FuelCost ###
    th_solitude = get_component(ThermalStandard, c_sys5_re, "Solitude")
    th_brighton = get_component(ThermalStandard, c_sys5_re, "Brighton")

    ### Update Brighton Cost ###
    DayAhead = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  23:00:00",
            "d/m/y  H:M:S",
        ),
    )
    DayAhead2 = DayAhead + Day(1)

    fuel_cost_day1 = Float64.(collect(101:124)) # Expensive Day 1
    fuel_cost_day2 = ones(24) # Cheap Day 2

    forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
    forecast_data[DayAhead[1]] = TimeArray(DayAhead, fuel_cost_day1)
    forecast_data[DayAhead2[1]] = TimeArray(DayAhead2, fuel_cost_day2)

    operation_cost_brighton = th_brighton.operation_cost
    io_curve =
        PiecewisePointCurve([(0.0, 0.0), (200.0, 2000.0), (400.0, 4800.0), (600.0, 8400.0)])
    operation_cost_brighton.variable = FuelCurve(io_curve, 1.0) # Use PWL for Brighton
    set_fuel_cost!(c_sys5_re, th_brighton, Deterministic("fuel_cost", forecast_data))

    ### Update Solitude Cost ###
    fuel_cost_day1 = ones(24) # Cheap Day 1
    fuel_cost_day2 = Float64.(collect(101:124)) # Expensive Day 2

    forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
    forecast_data[DayAhead[1]] = TimeArray(DayAhead, fuel_cost_day1)
    forecast_data[DayAhead2[1]] = TimeArray(DayAhead2, fuel_cost_day2)

    operation_cost_solitude = th_solitude.operation_cost
    operation_cost_solitude.variable = FuelCurve(LinearCurve(1.0), 1.0) # Use Linear for Solitude
    set_fuel_cost!(c_sys5_re, th_solitude, Deterministic("fuel_cost", forecast_data))

    return c_sys5_re
end

function build_c_sys5_re_only(; add_forecasts, add_single_time_series, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_re_only = PSY.System(
        100.0,
        nodes,
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_re_only))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            add_time_series!(
                c_sys5_re_only,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_re_only,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, r) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_re_only))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(ren_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = ren_timeseries_DA[t][ix]
        end
        if add_single_time_series
            add_time_series!(
                c_sys5_re_only,
                r,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_re_only,
                    r,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    return c_sys5_re_only
end

function build_c_sys5_hy(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    kwargs...,
)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_hy = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        [hydro_generators5(nodes)[1]],
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hy))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            add_time_series!(
                c_sys5_hy,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, r) in enumerate(PSY.get_components(PSY.HydroGen, c_sys5_hy))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
        end
        if add_single_time_series
            add_time_series!(
                c_sys5_hy,
                r,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    hydro_single_timeseries_DA;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy,
                    r,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    if add_reserves
        reserve_hy = reserve5_hy(PSY.get_components(PSY.HydroDispatch, c_sys5_hy))
        PSY.add_service!(
            c_sys5_hy,
            reserve_hy[1],
            PSY.get_components(PSY.HydroDispatch, c_sys5_hy),
        )
        PSY.add_service!(
            c_sys5_hy,
            reserve_hy[2],
            [collect(PSY.get_components(PSY.HydroDispatch, c_sys5_hy))[end]],
        )

        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_hy))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_hy,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_hy,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
    end

    return c_sys5_hy
end

function build_c_sys5_hy_turbine_energy(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    kwargs...,
)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_hyd = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    turb = hydro_turbines5_energy(nodes)[1]
    res = hydro_reservoir5_energy()[1]
    PSY.add_component!(c_sys5_hyd, turb)
    PSY.add_component!(c_sys5_hyd, res)
    set_downstream_turbines!(res, [turb])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            add_time_series!(
                c_sys5_hyd,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroTurbine, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_budget_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_budget_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_budget_single_ts_DA),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("hydro_budget", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data_inflow = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        forecast_data_target = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data_inflow[ini_time] = hydro_timeseries_DA[t][ix]
            forecast_data_target[ini_time] = storage_target_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("inflow", hydro_single_timeseries_DA),
            )
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("storage_target", storage_target_single_ts_DA),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("inflow", forecast_data_inflow),
                )
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("storage_target", forecast_data_target),
                )
            end
        end
    end
    if add_reserves
        reserve_hy = reserve5_hy(turb)
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[1],
            turb,
        )
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[2],
            turb,
        )

        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_hyd,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_hyd,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
    end

    return c_sys5_hyd
end

function build_c_sys5_hy_turbine_head(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    kwargs...,
)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_hyd = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    turb = hydro_turbines5_head(nodes)[1]
    res = hydro_reservoir5_head()[1]
    PSY.add_component!(c_sys5_hyd, turb)
    PSY.add_component!(c_sys5_hyd, res)
    set_downstream_turbines!(res, [turb])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data_inflow = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        forecast_data_outflow = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(inflow_ts_DA_water[t][ix])[1]
            forecast_data_inflow[ini_time] = inflow_ts_DA_water[t][ix]
            forecast_data_outflow[ini_time] = outflow_ts_DA_water[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("inflow", inflow_single_ts_DA_water),
            )
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("outflow", outflow_single_ts_DA_water),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("inflow", forecast_data_inflow),
                )
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("outflow", forecast_data_outflow),
                )
            end
        end
    end

    if add_reserves
        reserve_hy = reserve5_hy(turb)
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[1],
            turb,
        )
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[2],
            turb,
        )

        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_hyd,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_hyd,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
    end

    return c_sys5_hyd
end

function build_c_sys5_hy_cascading_turbine_energy(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    kwargs...,
)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_hyd = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    turb_up, turb_down = hydro_turbines5_cascading_energy(nodes)
    res_head, res_tail = hydro_reservoir5_cascading_energy()
    PSY.add_component!(c_sys5_hyd, turb_up)
    PSY.add_component!(c_sys5_hyd, turb_down)
    PSY.add_component!(c_sys5_hyd, res_head)
    PSY.add_component!(c_sys5_hyd, res_tail)
    set_downstream_turbines!(res_head, [turb_up])
    set_upstream_turbines!(res_tail, [turb_up])
    set_downstream_turbines!(res_tail, [turb_down])
    set_upstream_reservoirs!(res_tail, [res_head])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroTurbine, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_timeseries_DA[t][1])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][1]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_budget_DA[t][1])[1]
            forecast_data[ini_time] = hydro_budget_DA[t][1]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("hydro_budget", hydro_budget_single_ts_DA),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("hydro_budget", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data_inflow = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        forecast_data_target = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_timeseries_DA[t][1])[1]
            forecast_data_inflow[ini_time] = hydro_timeseries_DA[t][1]
            forecast_data_target[ini_time] = storage_target_DA[t][1]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("inflow", hydro_single_timeseries_DA),
            )
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("storage_target", storage_target_single_ts_DA),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("inflow", forecast_data_inflow),
                )
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("storage_target", forecast_data_target),
                )
            end
        end
    end
    if add_reserves
        reserve_hy = reserve5_hy(turb_down)
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[1],
            turb_down,
        )
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[2],
            turb_down,
        )

        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_hyd,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_hyd,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
    end

    return c_sys5_hyd
end

function build_c_sys5_hy_cascading_turbine_head(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    kwargs...,
)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_hyd = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    turb_up, turb_down = hydro_turbines5_cascading_head(nodes)
    res_head, res_tail = hydro_reservoir5_cascading_head()
    PSY.add_component!(c_sys5_hyd, turb_up)
    PSY.add_component!(c_sys5_hyd, turb_down)
    PSY.add_component!(c_sys5_hyd, res_head)
    PSY.add_component!(c_sys5_hyd, res_tail)
    set_downstream_turbines!(res_head, [turb_up])
    set_upstream_turbines!(res_tail, [turb_up])
    set_downstream_turbines!(res_tail, [turb_down])
    set_upstream_reservoirs!(res_tail, [res_head])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data_inflow = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        forecast_data_outflow = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(inflow_ts_DA_water[t][1])[1]
            forecast_data_inflow[ini_time] = inflow_ts_DA_water[t][1]
            forecast_data_outflow[ini_time] = outflow_ts_DA_water[t][1]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("inflow", inflow_single_ts_DA_water),
            )
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("outflow", outflow_single_ts_DA_water),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("inflow", forecast_data_inflow),
                )
                PSY.add_time_series!(
                    c_sys5_hyd,
                    h,
                    PSY.Deterministic("outflow", forecast_data_outflow),
                )
            end
        end
    end
    if add_reserves
        reserve_hy = reserve5_hy(turb_down)
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[1],
            turb_down,
        )
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[2],
            turb_down,
        )

        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_hyd,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_hyd,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
    end

    return c_sys5_hyd
end

function build_c_sys5_hyd(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    nodes = nodes5()
    hydros = hydro_generators5(nodes)
    reservoir = hydro_reservoir5_energy()
    c_sys5_hyd = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        [hydros[2]],
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )
    add_component!(c_sys5_hyd, reservoir[1])
    set_downstream_turbines!(reservoir[1], [hydros[2]])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hyd,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(HydroGen, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_budget_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_budget_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("hydro_budget", hydro_budget_single_ts_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.Deterministic("hydro_budget", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data_inflow = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        forecast_data_target = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data_inflow[ini_time] = hydro_timeseries_DA[t][ix]
            forecast_data_target[ini_time] = storage_target_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("inflow", hydro_single_timeseries_DA),
            )
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("storage_target", storage_target_single_ts_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.Deterministic("inflow", forecast_data_inflow),
            )
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.Deterministic("storage_target", forecast_data_target),
            )
        end
    end
    if add_reserves
        reserve_hy = reserve5_hy(PSY.get_components(PSY.HydroTurbine, c_sys5_hyd))
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[1],
            PSY.get_components(PSY.HydroTurbine, c_sys5_hyd),
        )
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[2],
            PSY.get_components(PSY.HydroTurbine, c_sys5_hyd),
        )
        # ORDC curve
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[3],
            PSY.get_components(PSY.HydroTurbine, c_sys5_hyd),
        )
        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_hyd,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            elseif add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    serv,
                    PSY.Deterministic("requirement", forecast_data),
                )
            end
        end
        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_hyd))
            PSY.set_variable_cost!(
                c_sys5_hyd,
                serv,
                ORDC_cost,
            )
        end
    end

    return c_sys5_hyd
end

function build_c_sys5_hyd_ems(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    nodes = nodes5()
    hydros = hydro_generators5(nodes)
    reservoir = hydro_reservoir5_energy()
    c_sys5_hyd = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        [hydros[2]],
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )
    add_component!(c_sys5_hyd, reservoir[1])
    set_downstream_turbines!(reservoir[1], [hydros[2]])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hyd,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(HydroGen, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_budget_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_budget_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("hydro_budget", hydro_budget_single_ts_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.Deterministic("hydro_budget", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hyd))
        forecast_data_inflow = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        forecast_data_target = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data_inflow[ini_time] = hydro_timeseries_DA[t][ix]
            forecast_data_target[ini_time] = storage_target_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("inflow", hydro_single_timeseries_DA),
            )
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.SingleTimeSeries("storage_target", storage_target_single_ts_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.Deterministic("inflow", forecast_data_inflow),
            )
            PSY.add_time_series!(
                c_sys5_hyd,
                h,
                PSY.Deterministic("storage_target", forecast_data_target),
            )
        end
    end
    if add_reserves
        reserve_hy = reserve5_hy(PSY.get_components(PSY.HydroTurbine, c_sys5_hyd))
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[1],
            PSY.get_components(PSY.HydroTurbine, c_sys5_hyd),
        )
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[2],
            PSY.get_components(PSY.HydroTurbine, c_sys5_hyd),
        )
        # ORDC curve
        PSY.add_service!(
            c_sys5_hyd,
            reserve_hy[3],
            PSY.get_components(PSY.HydroTurbine, c_sys5_hyd),
        )
        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_hyd,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            elseif add_forecasts
                PSY.add_time_series!(
                    c_sys5_hyd,
                    serv,
                    PSY.Deterministic("requirement", forecast_data),
                )
            end
        end
        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_hyd))
            PSY.set_variable_cost!(
                c_sys5_hyd,
                serv,
                ORDC_cost,
            )
        end
    end

    return c_sys5_hyd
end

function build_c_sys5_bat(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true)
    nodes = nodes5()
    c_sys5_bat = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes),
        battery5(nodes);
        time_series_in_memory = time_series_in_memory,
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_bat))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_bat,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_bat,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, r) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_bat))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(ren_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = ren_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_bat,
                r,
                PSY.SingleTimeSeries("max_active_power", ren_single_timeseries_DA[ix]),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_bat,
                    r,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    if add_reserves
        reserve_bat = reserve5_re(PSY.get_components(PSY.RenewableDispatch, c_sys5_bat))
        PSY.add_service!(
            c_sys5_bat,
            reserve_bat[1],
            PSY.get_components(PSY.EnergyReservoirStorage, c_sys5_bat),
        )
        PSY.add_service!(
            c_sys5_bat,
            reserve_bat[2],
            PSY.get_components(PSY.EnergyReservoirStorage, c_sys5_bat),
        )
        # ORDC
        PSY.add_service!(
            c_sys5_bat,
            reserve_bat[3],
            PSY.get_components(PSY.EnergyReservoirStorage, c_sys5_bat),
        )
        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_bat,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_bat,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_bat))
            PSY.set_variable_cost!(
                c_sys5_bat,
                serv,
                ORDC_cost,
            )
        end
    end

    return c_sys5_bat
end

function build_c_sys5_hydro_pump_energy(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true)
    nodes = nodes5()
    c_sys5_bat = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes),
        battery5(nodes);
        time_series_in_memory = time_series_in_memory,
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_bat))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_bat,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_bat,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, r) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_bat))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(ren_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = ren_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_bat,
                r,
                PSY.SingleTimeSeries("max_active_power", ren_single_timeseries_DA[ix]),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_bat,
                    r,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    if add_reserves
        reserve_bat = reserve5_re(PSY.get_components(PSY.RenewableDispatch, c_sys5_bat))
        PSY.add_service!(
            c_sys5_bat,
            reserve_bat[1],
            PSY.get_components(PSY.EnergyReservoirStorage, c_sys5_bat),
        )
        PSY.add_service!(
            c_sys5_bat,
            reserve_bat[2],
            PSY.get_components(PSY.EnergyReservoirStorage, c_sys5_bat),
        )
        # ORDC
        PSY.add_service!(
            c_sys5_bat,
            reserve_bat[3],
            PSY.get_components(PSY.EnergyReservoirStorage, c_sys5_bat),
        )
        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_bat,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_bat,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_bat))
            PSY.set_variable_cost!(
                c_sys5_bat,
                serv,
                ORDC_cost,
            )
        end
    end
    bat = first(PSY.get_components(EnergyReservoirStorage, c_sys5_bat))

    convert_to_hydropump!(bat, c_sys5_bat)
    PSY.remove_component!(c_sys5_bat, bat)

    for (ix, l) in enumerate(PSY.get_components(PSY.HydroPumpTurbine, c_sys5_bat))
        forecast_data_power = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        forecast_data_cap = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time_power = TimeSeries.timestamp(hydro_pump_power_timeseries_DA[t][ix])[1]
            forecast_data_power[ini_time_power] = hydro_pump_power_timeseries_DA[t][ix]
            ini_time_cap = TimeSeries.timestamp(hydro_pump_cap_timeseries_DA[t][ix])[1]
            forecast_data_cap[ini_time_cap] = hydro_pump_cap_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_bat,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    hydro_pump_power_single_timeseries_DA;
                ),
            )
            PSY.add_time_series!(
                c_sys5_bat,
                l,
                PSY.SingleTimeSeries(
                    "capacity",
                    hydro_pump_cap_single_timeseries_DA;
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_bat,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data_power),
                )
                PSY.add_time_series!(
                    c_sys5_bat,
                    l,
                    PSY.Deterministic("capacity", forecast_data_cap),
                )
            end
        end
    end

    return c_sys5_bat
end

function build_c_sys5_il(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    kwargs...,
)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_il = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_il))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_il,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_il,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, i) in enumerate(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_il))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(Iload_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = Iload_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_il,
                i,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_DA;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_il,
                i,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end

    if add_reserves
        reserve_il = reserve5_il(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_il))
        PSY.add_service!(
            c_sys5_il,
            reserve_il[1],
            PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_il),
        )
        PSY.add_service!(
            c_sys5_il,
            reserve_il[2],
            [collect(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_il))[end]],
        )
        # ORDC
        PSY.add_service!(
            c_sys5_il,
            reserve_il[3],
            PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_il),
        )
        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_il))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_il,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            elseif add_forecasts
                PSY.add_time_series!(
                    c_sys5_il,
                    serv,
                    PSY.Deterministic("requirement", forecast_data),
                )
            end
        end
        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_il))
            PSY.set_variable_cost!(
                c_sys5_il,
                serv,
                ORDC_cost,
            )
        end
    end

    return c_sys5_il
end

function build_c_sys5_dc(; add_forecasts, add_single_time_series, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_dc = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5_dc(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_dc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_dc,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_dc,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, r) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_dc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(ren_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = ren_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_dc,
                r,
                PSY.SingleTimeSeries("max_active_power", ren_single_timeseries_DA[ix]),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_dc,
                    r,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    return c_sys5_dc
end

function build_c_sys5_events(; add_forecasts, raw_data, sys_kwargs...)
    nodes = nodes5()
    c_sys5 = PSY.System(
        100.0,
        nodes,
        thermal_generators5_events(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        sys_kwargs...,
    )
    pv_device = PSY.RenewableDispatch(
        "PVBus5",
        true,
        nodes[3],
        0.0,
        0.0,
        3.84,
        PrimeMovers.PVe,
        (min = 0.0, max = 0.0),
        1.0,
        RenewableGenerationCost(nothing),
        100.0,
    )
    wind_device = PSY.RenewableDispatch(
        "WindBus1",
        true,
        nodes[1],
        0.0,
        0.0,
        4.51,
        PrimeMovers.WT,
        (min = 0.0, max = 0.0),
        1.0,
        RenewableGenerationCost(nothing),
        100.0,
    )
    PSY.add_component!(c_sys5, pv_device)
    PSY.add_component!(c_sys5, wind_device)
    constant_reserve = constant_reserve5()
    PSY.add_component!(c_sys5, constant_reserve)
    for g in PSY.get_components(ThermalStandard, c_sys5)
        add_service!(g, constant_reserve, c_sys5)
    end
    timeseries_dataset =
        HDF5.h5read(joinpath(DATA_DIR, "5-Bus", "PJM_5_BUS_7_DAYS.h5"), "Time Series Data")
    refdate = first(DayAhead)
    da_load_time_series = DateTime[]
    da_load_time_series_val = Float64[]

    for i in 1:2
        for v in timeseries_dataset["DA Load Data"]["DA_LOAD_DAY_$(i)"]
            h = refdate + Hour(v.HOUR + (i - 1) * 24)
            push!(da_load_time_series, h)
            push!(da_load_time_series_val, v.LOAD)
        end
    end
    re_timeseries = Dict(
        "PVBus5" => CSV.read(
            joinpath(
                DATA_DIR,
                "5-Bus",
                "5bus_ts",
                "gen",
                "Renewable",
                "PV",
                "da_solar.csv",
            ),
            DataFrame,
        )[
            1:48,
            :SolarBusC,
        ],
        "WindBus1" => CSV.read(
            joinpath(
                DATA_DIR,
                "5-Bus",
                "5bus_ts",
                "gen",
                "Renewable",
                "WIND",
                "da_wind.csv",
            ),
            DataFrame,
        )[
            1:48,
            :WindBusA,
        ],
    )
    re_timeseries["WindBus1"] = re_timeseries["WindBus1"] ./ 451

    bus_dist_fact = Dict("Bus2" => 0.33, "Bus3" => 0.33, "Bus4" => 0.34)
    peak_load = maximum(da_load_time_series_val)
    if add_forecasts
        for (ix, l) in enumerate(PSY.get_components(PowerLoad, c_sys5))
            set_max_active_power!(l, bus_dist_fact[PSY.get_name(l)] * peak_load / 100)
            add_time_series!(
                c_sys5,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    TimeArray(da_load_time_series, da_load_time_series_val ./ peak_load),
                ),
            )
        end
        for (ix, i) in enumerate(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5))
            PSY.add_time_series!(
                c_sys5,
                i,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_DA;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
        for (ix, g) in enumerate(PSY.get_components(RenewableDispatch, c_sys5))
            add_time_series!(
                c_sys5,
                g,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    TimeArray(da_load_time_series, re_timeseries[PSY.get_name(g)]),
                ),
            )
        end
    end
    return c_sys5
end

function build_c_sys5_events_rt(; add_forecasts, raw_data, sys_kwargs...)
    nodes = nodes5()
    c_sys5 = PSY.System(
        100.0,
        nodes,
        thermal_generators5_events(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        sys_kwargs...,
    )
    pv_device = PSY.RenewableDispatch(
        "PVBus5",
        true,
        nodes[3],
        0.0,
        0.0,
        3.84,
        PrimeMovers.PVe,
        (min = 0.0, max = 0.0),
        1.0,
        RenewableGenerationCost(nothing),
        100.0,
    )
    wind_device = PSY.RenewableDispatch(
        "WindBus1",
        true,
        nodes[1],
        0.0,
        0.0,
        4.51,
        PrimeMovers.WT,
        (min = 0.0, max = 0.0),
        1.0,
        RenewableGenerationCost(nothing),
        100.0,
    )
    PSY.add_component!(c_sys5, pv_device)
    PSY.add_component!(c_sys5, wind_device)
    constant_reserve = constant_reserve5()
    PSY.add_component!(c_sys5, constant_reserve)
    for g in PSY.get_components(ThermalStandard, c_sys5)
        add_service!(g, constant_reserve, c_sys5)
    end
    timeseries_dataset =
        HDF5.h5read(joinpath(DATA_DIR, "5-Bus", "PJM_5_BUS_7_DAYS.h5"), "Time Series Data")
    refdate = first(DayAhead)
    rt_load_time_series = DateTime[]
    rt_load_time_series_val = Float64[]
    # This scale factor is empirically determined to ensure test cases for events are feasible in PSI:
    rt_load_scale_factor = 0.9
    for i in 1:2
        for v in timeseries_dataset["Actual Load Data"]["ACTUAL_LOAD_DAY_$(i).xls"]
            h = refdate + Second(round(v.Time * 86400)) + Day(i - 1)
            push!(rt_load_time_series, h)
            push!(rt_load_time_series_val, v.Load * rt_load_scale_factor)
        end
    end

    re_timeseries = Dict(
        "PVBus5" => CSV.read(
            joinpath(
                DATA_DIR,
                "5-Bus",
                "5bus_ts",
                "gen",
                "Renewable",
                "PV",
                "rt_solar.csv",
            ),
            DataFrame,
        )[
            1:576,
            :SolarBusC,
        ],
        "WindBus1" => CSV.read(
            joinpath(
                DATA_DIR,
                "5-Bus",
                "5bus_ts",
                "gen",
                "Renewable",
                "WIND",
                "rt_wind.csv",
            ),
            DataFrame,
        )[
            1:576,
            :WindBusA,
        ],
    )

    re_timeseries["WindBus1"] = re_timeseries["WindBus1"] ./ 451
    re_timeseries["PVBus5"] = re_timeseries["PVBus5"] ./ maximum(re_timeseries["PVBus5"])

    rt_re_time_stamps =
        collect(DateTime("2024-01-01T00:00:00"):Minute(5):DateTime("2024-01-02T23:55:00"))

    rt_timearray = TimeArray(rt_load_time_series, rt_load_time_series_val)
    rt_timearray = collapse(rt_timearray, Minute(5), first, TimeSeries.mean)
    bus_dist_fact = Dict("Bus2" => 0.33, "Bus3" => 0.33, "Bus4" => 0.34)
    peak_load = maximum(rt_load_time_series_val)
    if add_forecasts
        for (ix, l) in enumerate(PSY.get_components(PowerLoad, c_sys5))
            set_max_active_power!(l, bus_dist_fact[PSY.get_name(l)] * peak_load / 100)
            rt_timearray =
                TimeArray(rt_load_time_series, rt_load_time_series_val ./ peak_load)
            rt_timearray = collapse(rt_timearray, Minute(5), first, TimeSeries.mean)
            add_time_series!(
                c_sys5,
                l,
                PSY.SingleTimeSeries("max_active_power", rt_timearray),
            )
        end
        for (ix, l) in enumerate(PSY.get_components(InterruptiblePowerLoad, c_sys5))
            rt_timearray =
                TimeArray(rt_load_time_series, rt_load_time_series_val ./ peak_load)
            rt_timearray = collapse(rt_timearray, Minute(5), first, TimeSeries.mean)
            add_time_series!(
                c_sys5,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_RT;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
        for (ix, g) in enumerate(PSY.get_components(RenewableDispatch, c_sys5))
            add_time_series!(
                c_sys5,
                g,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    TimeArray(rt_re_time_stamps, re_timeseries[PSY.get_name(g)]),
                ),
            )
        end
    end
    return c_sys5
end

#=
function build_c_sys5_reg(; add_forecasts, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()

    c_sys5_reg = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        branches5(nodes),
        sys_kwargs...,
    )

    area = PSY.Area("1")
    PSY.add_component!(c_sys5_reg, area)
    [PSY.set_area!(b, area) for b in PSY.get_components(PSY.ACBus, c_sys5_reg)]
    AGC_service = PSY.AGC(;
        name = "AGC_Area1",
        available = true,
        bias = 739.0,
        K_p = 2.5,
        K_i = 0.1,
        K_d = 0.0,
        delta_t = 4,
        area = first(PSY.get_components(PSY.Area, c_sys5_reg)),
    )
    #add_component!(c_sys5_reg, AGC_service)
    if add_forecasts
        for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_reg))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            PSY.add_time_series!(
                c_sys5_reg,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
        for (_, l) in enumerate(PSY.get_components(PSY.ThermalStandard, c_sys5_reg))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = PSY.TimeSeries.timestamp(load_timeseries_DA[t][1])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][1]
            end
            PSY.add_time_series!(
                c_sys5_reg,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end

    contributing_devices = Vector()
    for g in PSY.get_components(PSY.Generator, c_sys5_reg)
        droop =
            if isa(g, PSY.ThermalStandard)
                0.04 * PSY.get_base_power(g)
            else
                0.05 * PSY.get_base_power(g)
            end
        p_factor = (up = 1.0, dn = 1.0)
        t = PSY.RegulationDevice(g; participation_factor = p_factor, droop = droop)
        PSY.add_component!(c_sys5_reg, t)
        push!(contributing_devices, t)
    end
    PSY.add_service!(c_sys5_reg, AGC_service, contributing_devices)
    return c_sys5_reg
end
=#

function build_sys_ramp_testing(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    gen_ramp = [
        PSY.ThermalStandard(;
            name = "Alta",
            available = true,
            status = true,
            bus = node,
            active_power = 0.20, # Active power
            reactive_power = 0.010,
            rating = 0.5,
            prime_mover_type = PSY.PrimeMovers.ST,
            fuel = PSY.ThermalFuels.COAL,
            active_power_limits = (min = 0.0, max = 0.40),
            reactive_power_limits = nothing,
            ramp_limits = nothing,
            time_limits = nothing,
            operation_cost = ThermalGenerationCost(
                CostCurve(QuadraticCurve(0.0, 14.0, 0.0)),
                0.0,
                4.0,
                2.0,
            ),
            base_power = 100.0,
        ),
        PSY.ThermalStandard(;
            name = "Park City",
            available = true,
            status = true,
            bus = node,
            active_power = 0.70, # Active Power
            reactive_power = 0.20,
            rating = 2.0,
            prime_mover_type = PSY.PrimeMovers.ST,
            fuel = PSY.ThermalFuels.COAL,
            active_power_limits = (min = 0.7, max = 2.20),
            reactive_power_limits = nothing,
            ramp_limits = (up = 0.010625 * 2.0, down = 0.010625 * 2.0),
            time_limits = nothing,
            operation_cost = ThermalGenerationCost(
                CostCurve(QuadraticCurve(0.0, 15.0, 0.0)),
                0.0,
                1.5,
                0.75,
            ),
            base_power = 100.0,
        ),
    ]
    DA_ramp = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  4:00:00",
            "d/m/y  H:M:S",
        ),
    )
    ramp_load = [0.9, 1.1, 2.485, 2.175, 0.9]
    ts_dict = SortedDict(DA_ramp[1] => ramp_load)
    load_forecast_ramp = PSY.Deterministic("max_active_power", ts_dict, Hour(1))
    ramp_test_sys = PSY.System(100.0, sys_kwargs...)
    PSY.add_component!(ramp_test_sys, node)
    PSY.add_component!(ramp_test_sys, load)
    PSY.add_component!(ramp_test_sys, gen_ramp[1])
    PSY.add_component!(ramp_test_sys, gen_ramp[2])
    PSY.add_time_series!(ramp_test_sys, load, load_forecast_ramp)
    return ramp_test_sys
end

function build_sys_10bus_ac_dc(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes10()
    nodesdc = nodes10_dc()
    # Renumber DC buses to avoid conflicts with AC bus numbers (1-10)
    # ACBus and DCBus share a single bus-number namespace in PowerSystems
    for n in nodesdc
        PSY.set_number!(n, PSY.get_number(n) + 100)
    end
    branchesdc = branches10_dc(nodesdc)
    ipcs = ipcs_10bus(nodes, nodesdc)

    sys = PSY.System(
        100.0,
        nodes,
        thermal_generators10(nodes),
        loads10(nodes),
        branches10_ac(nodes);
        sys_kwargs...,
    )

    # Add DC Buses
    for n in nodesdc
        PSY.add_component!(sys, n)
    end
    # Add DC Branches
    for l in branchesdc
        PSY.add_component!(sys, l)
    end
    # Add IPCs
    for i in ipcs
        PSY.add_component!(sys, i)
    end

    # Add TimeSeries to Loads
    resolution = Dates.Hour(1)
    loads = PSY.get_components(PowerLoad, sys)
    for l in loads
        if occursin("nodeB", PSY.get_name(l))
            data = Dict(DateTime("2020-01-01T00:00:00") => loadbusB_ts_DA)
            PSY.add_time_series!(
                sys,
                l,
                Deterministic("max_active_power", data, resolution),
            )
        elseif occursin("nodeC", PSY.get_name(l))
            data = Dict(DateTime("2020-01-01T00:00:00") => loadbusC_ts_DA)
            PSY.add_time_series!(
                sys,
                l,
                Deterministic("max_active_power", data, resolution),
            )
        else
            data = Dict(DateTime("2020-01-01T00:00:00") => loadbusD_ts_DA)
            PSY.add_time_series!(
                sys,
                l,
                Deterministic("max_active_power", data, resolution),
            )
        end
    end

    return sys
end

function build_c_sys5_uc(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    nodes = nodes5()
    c_sys5_uc = PSY.System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_uc,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_uc,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    if add_reserves
        reserve_uc = reserve5(PSY.get_components(PSY.ThermalStandard, c_sys5_uc))
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[1],
            PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
        )
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[2],
            [collect(PSY.get_components(PSY.ThermalStandard, c_sys5_uc))[end]],
        )
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[3],
            PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
        )
        # ORDC Curve
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[4],
            PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
        )
        for serv in PSY.get_components(PSY.VariableReserve, c_sys5_uc)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_uc,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_uc,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end

        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_uc))
            PSY.set_variable_cost!(
                c_sys5_uc,
                serv,
                ORDC_cost,
            )
        end
    end
    return c_sys5_uc
end

function build_c_sys5_uc_non_spin(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    nodes = nodes5()
    c_sys5_uc = PSY.System(
        100.0,
        nodes,
        vcat(thermal_pglib_generators5(nodes), thermal_generators5_uc_testing(nodes)),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_uc,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_uc,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    if add_reserves
        reserve_uc = reserve5(PSY.get_components(PSY.ThermalStandard, c_sys5_uc))
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[1],
            PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
        )
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[2],
            [collect(PSY.get_components(PSY.ThermalStandard, c_sys5_uc))[end]],
        )
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[3],
            PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
        )
        # ORDC Curve
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[4],
            PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
        )
        # Non-spinning reserve
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[5],
            PSY.get_components(PSY.ThermalGen, c_sys5_uc),
        )

        for serv in PSY.get_components(PSY.VariableReserve, c_sys5_uc)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_uc,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_uc,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end

        for serv in PSY.get_components(PSY.VariableReserveNonSpinning, c_sys5_uc)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_uc,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_uc,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end

        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_uc))
            PSY.set_variable_cost!(
                c_sys5_uc,
                serv,
                ORDC_cost,
            )
        end
    end
    return c_sys5_uc
end

function build_c_sys5_uc_re(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    nodes = nodes5()
    c_sys5_uc = PSY.System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_uc,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_uc,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, r) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = ren_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_uc,
                r,
                PSY.SingleTimeSeries("max_active_power", ren_single_timeseries_DA[ix]),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_uc,
                    r,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, i) in enumerate(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(Iload_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = Iload_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_uc,
                i,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_DA;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_uc,
                    i,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    if add_reserves
        reserve_uc = reserve5(PSY.get_components(PSY.ThermalStandard, c_sys5_uc))
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[1],
            PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
        )
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[2],
            [collect(PSY.get_components(PSY.ThermalStandard, c_sys5_uc))[end]],
        )
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[3],
            PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
        )
        # ORDC Curve
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[4],
            PSY.get_components(PSY.ThermalStandard, c_sys5_uc),
        )
        for serv in PSY.get_components(PSY.VariableReserve, c_sys5_uc)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_uc,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_uc,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end

        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, c_sys5_uc))
            PSY.set_variable_cost!(
                c_sys5_uc,
                serv,
                ORDC_cost,
            )
        end
    end

    return c_sys5_uc
end

function build_c_sys5_pwl_uc(; raw_data, kwargs...)
    c_sys5_uc = build_c_sys5_uc(; raw_data, kwargs...)
    thermal = thermal_generators5_pwl(collect(PSY.get_components(PSY.ACBus, c_sys5_uc)))
    for d in thermal
        PSY.add_component!(c_sys5_uc, d)
    end
    return c_sys5_uc
end

function build_c_sys5_ed(; add_forecasts, add_single_time_series, add_reserves, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_ed = PSY.System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2 # loop over days
            ta = load_timeseries_DA[t][ix]
            for i in 1:length(ta) # loop over hours
                ini_time = timestamp(ta[i]) #get the hour
                data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2 # loop over days
            ta = ren_timeseries_DA[t][ix]
            for i in 1:length(ta) # loop over hours
                ini_time = timestamp(ta[i]) #get the hour
                data = when(ren_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_ed,
                l,
                PSY.SingleTimeSeries("max_active_power", ren_single_timeseries_RT[ix]),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2 # loop over days
            ta = Iload_timeseries_DA[t][ix]
            for i in 1:length(ta) # loop over hours
                ini_time = timestamp(ta[i]) #get the hour
                data = when(Iload_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_RT;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    if add_reserves
        reserve_ed = reserve5(PSY.get_components(PSY.ThermalStandard, c_sys5_ed))
        PSY.add_service!(
            c_sys5_ed,
            reserve_ed[1],
            PSY.get_components(PSY.ThermalStandard, c_sys5_ed),
        )
        PSY.add_service!(
            c_sys5_ed,
            reserve_ed[2],
            [collect(PSY.get_components(PSY.ThermalStandard, c_sys5_ed))[end]],
        )
        PSY.add_service!(
            c_sys5_ed,
            reserve_ed[3],
            PSY.get_components(PSY.ThermalStandard, c_sys5_ed),
        )
        for serv in PSY.get_components(PSY.VariableReserve, c_sys5_ed)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2 # loop over days
                ta_DA = Reserve_ts[t]
                data_5min = repeat(values(ta_DA); inner = 12)
                reserve_timeseries_RT =
                    TimeSeries.TimeArray(RealTime + Day(t - 1), data_5min)
                # loop over hours
                for ini_time in timestamp(ta_DA) #get the initial hour
                    # Construct TimeSeries
                    data = when(reserve_timeseries_RT, hour, hour(ini_time)) # get the subset ts for that hour
                    forecast_data[ini_time] = data
                end
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_ed,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts_RT),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_ed,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
    end
    return c_sys5_ed
end

function build_c_sys5_pwl_ed(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    kwargs...,
)
    c_sys5_ed = build_c_sys5_ed(;
        add_forecasts,
        add_single_time_series,
        add_reserves,
        raw_data,
        kwargs...,
    )
    thermal = thermal_generators5_pwl(collect(PSY.get_components(PSY.ACBus, c_sys5_ed)))
    for d in thermal
        PSY.add_component!(c_sys5_ed, d)
    end
    return c_sys5_ed
end

#raw_data not assigned
function build_c_sys5_pwl_ed_nonconvex(; add_forecasts, add_single_time_series, kwargs...)
    c_sys5_ed = build_c_sys5_ed(; add_forecasts, add_single_time_series, kwargs...)
    thermal =
        thermal_generators5_pwl_nonconvex(collect(PSY.get_components(PSY.ACBus, c_sys5_ed)))
    for d in thermal
        PSY.add_component!(c_sys5_ed, d)
    end
    return c_sys5_ed
end

function build_c_sys5_hy_uc(; add_forecasts, add_single_time_series, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    hydros = hydro_generators5(nodes)
    reservoir = hydro_reservoir5_energy()
    c_sys5_hy_uc = PSY.System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        hydros,
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )
    add_component!(c_sys5_hy_uc, reservoir[1])
    set_downstream_turbines!(reservoir[1], [hydros[2]])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_uc,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroTurbine, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(storage_target_DA[t][ix])[1]
            forecast_data[ini_time] = storage_target_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("storage_target", storage_target_single_ts_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("storage_target", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix] .* 0.8
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("inflow", hydro_single_timeseries_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("inflow", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_budget_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_budget_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("hydro_budget", hydro_budget_single_ts_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("hydro_budget", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroDispatch, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, r) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = ren_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                r,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                r,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, i) in
        enumerate(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(Iload_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = Iload_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                i,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_DA;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                i,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end

    return c_sys5_hy_uc
end

function build_c_sys5_hy_ems_uc(;
    add_forecasts,
    add_single_time_series,
    raw_data,
    kwargs...,
)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    hydros = hydro_generators5(nodes)
    reservoir = hydro_reservoir5_energy()
    c_sys5_hy_uc = PSY.System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        hydros,
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )
    add_component!(c_sys5_hy_uc, reservoir[1])
    set_downstream_turbines!(reservoir[1], [hydros[2]])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_uc,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroTurbine, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(storage_target_DA[t][ix])[1]
            forecast_data[ini_time] = storage_target_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("storage_target", storage_target_single_ts_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("storage_target", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix] .* 0.8
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("inflow", hydro_single_timeseries_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("inflow", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = TimeSeries.timestamp(hydro_budget_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_budget_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("hydro_budget", hydro_budget_single_ts_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("hydro_budget", forecast_data),
            )
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroDispatch, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                h,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, r) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = ren_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                r,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                r,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end
    for (ix, i) in
        enumerate(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_hy_uc))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ini_time = timestamp(Iload_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = Iload_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_uc,
                i,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_DA;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        elseif add_forecasts
            PSY.add_time_series!(
                c_sys5_hy_uc,
                i,
                PSY.Deterministic("max_active_power", forecast_data),
            )
        end
    end

    return c_sys5_hy_uc
end

function build_c_sys5_hy_ed(; add_forecasts, add_single_time_series, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    hydros = hydro_generators5(nodes)
    reservoir = hydro_reservoir5_energy()
    c_sys5_hy_ed = PSY.System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        hydros,
        renewable_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )
    add_component!(c_sys5_hy_ed, reservoir[1])
    set_downstream_turbines!(reservoir[1], [hydros[2]])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2 # loop over days
            ta = load_timeseries_DA[t][ix]
            for i in 1:length(ta) # loop over hours
                ini_time = timestamp(ta[i]) #get the hour
                data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroTurbine, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = ren_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(ren_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = storage_target_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(storage_target_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries("storage_target", storage_target_single_ts_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("storage_target", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries("inflow", hydro_single_timeseries_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("inflow", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_budget_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_budget_RT[t][ix] .* 0.8, hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                h,
                PSY.SingleTimeSeries("hydro_budget", hydro_budget_single_ts_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    h,
                    PSY.Deterministic("hydro_budget", forecast_data),
                )
            end
        end
    end
    for (ix, l) in
        enumerate(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = Iload_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(Iload_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_RT;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroDispatch, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    return c_sys5_hy_ed
end

function build_c_sys5_hy_ems_ed(;
    add_forecasts,
    add_single_time_series,
    raw_data,
    kwargs...,
)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    hydros = hydro_generators5(nodes)
    reservoir = hydro_reservoir5_energy()
    c_sys5_hy_ed = PSY.System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        hydros,
        renewable_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )
    add_component!(c_sys5_hy_ed, reservoir[1])
    set_downstream_turbines!(reservoir[1], [hydros[2]])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2 # loop over days
            ta = load_timeseries_DA[t][ix]
            for i in 1:length(ta) # loop over hours
                ini_time = timestamp(ta[i]) #get the hour
                data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroTurbine, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = ren_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(ren_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = storage_target_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(storage_target_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries("storage_target", storage_target_single_ts_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("storage_target", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries("inflow", hydro_single_timeseries_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("inflow", forecast_data),
                )
            end
        end
    end
    for (ix, h) in enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_budget_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_budget_RT[t][ix] .* 0.8, hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                h,
                PSY.SingleTimeSeries("hydro_budget", hydro_budget_single_ts_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    h,
                    PSY.Deterministic("hydro_budget", forecast_data),
                )
            end
        end
    end
    for (ix, l) in
        enumerate(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = Iload_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(Iload_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_RT;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroDispatch, c_sys5_hy_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_hy_ed,
                l,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_hy_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    return c_sys5_hy_ed
end

function build_c_sys5_phes_ed(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    kwargs...,
)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_phes_ed = PSY.System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        phes5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )
    head_reservoir = PSY.get_component(HydroReservoir, c_sys5_phes_ed, "Head Reservoir")
    tail_reservoir = PSY.get_component(HydroReservoir, c_sys5_phes_ed, "Tail Reservoir")
    hydro_pump = PSY.get_component(HydroPumpTurbine, c_sys5_phes_ed, "HydroPumpTurbine")
    set_downstream_turbines!(head_reservoir, [hydro_pump])
    set_upstream_turbines!(tail_reservoir, [hydro_pump])

    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_phes_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2 # loop over days
            ta = load_timeseries_DA[t][ix]
            for i in 1:length(ta) # loop over hours
                ini_time = timestamp(ta[i]) #get the hour
                data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_phes_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_phes_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroGen, c_sys5_phes_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_phes_ed,
                l,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_phes_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_phes_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = ren_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(ren_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_phes_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_phes_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroPumpTurbine, c_sys5_phes_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_phes_ed,
                head_reservoir,
                PSY.SingleTimeSeries("initial_level", hydro_single_timeseries_RT),
            )
            PSY.add_time_series!(
                c_sys5_phes_ed,
                tail_reservoir,
                PSY.SingleTimeSeries("initial_level", hydro_single_timeseries_RT),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_phes_ed,
                    head_reservoir,
                    PSY.Deterministic("initial_level", forecast_data),
                )
                PSY.add_time_series!(
                    c_sys5_phes_ed,
                    tail_reservoir,
                    PSY.Deterministic("initial_level", forecast_data),
                )
            end
        end
    end
    for (ix, l) in enumerate(PSY.get_components(PSY.HydroPumpTurbine, c_sys5_phes_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = hydro_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(hydro_timeseries_RT[t][ix] .* 0.8, hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_phes_ed,
                head_reservoir,
                PSY.SingleTimeSeries(
                    "inflow",
                    TimeSeries.TimeArray(
                        timestamp(hydro_single_timeseries_RT),
                        values(hydro_single_timeseries_RT) .* 0.8,
                    ),
                ),
            )
            PSY.add_time_series!(
                c_sys5_phes_ed,
                tail_reservoir,
                PSY.SingleTimeSeries(
                    "inflow",
                    TimeSeries.TimeArray(
                        timestamp(hydro_single_timeseries_RT),
                        values(hydro_single_timeseries_RT) .* 0.8,
                    ),
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_phes_ed,
                    head_reservoir,
                    PSY.Deterministic("inflow", forecast_data),
                )
                PSY.add_time_series!(
                    c_sys5_phes_ed,
                    tail_reservoir,
                    PSY.Deterministic("outflow", forecast_data),
                )
            end
        end
    end
    for (ix, l) in
        enumerate(PSY.get_components(PSY.InterruptiblePowerLoad, c_sys5_phes_ed))
        forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
        for t in 1:2
            ta = Iload_timeseries_DA[t][ix]
            for i in 1:length(ta)
                ini_time = timestamp(ta[i])
                data = when(Iload_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                forecast_data[ini_time[1]] = data
            end
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_phes_ed,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    Iload_single_timeseries_RT;
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_phes_ed,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end

    if add_reserves
        reserve_uc =
            reserve5_phes(PSY.get_components(PSY.HydroPumpTurbine, c_sys5_phes_ed))
        PSY.add_service!(
            c_sys5_phes_ed,
            reserve_uc[1],
            PSY.get_components(PSY.HydroPumpTurbine, c_sys5_phes_ed),
        )
        PSY.add_service!(
            c_sys5_phes_ed,
            reserve_uc[2],
            [collect(PSY.get_components(PSY.HydroPumpTurbine, c_sys5_phes_ed))[end]],
        )

        for serv in PSY.get_components(PSY.VariableReserve, c_sys5_phes_ed)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2 # loop over days
                ta_DA = Reserve_ts[t]
                data_5min = repeat(values(ta_DA); inner = 12)
                reserve_timeseries_RT =
                    TimeSeries.TimeArray(RealTime + Day(t - 1), data_5min)
                # loop over hours
                for ini_time in timestamp(ta_DA) #get the initial hour
                    # Construct TimeSeries
                    data = when(reserve_timeseries_RT, hour, hour(ini_time)) # get the subset ts for that hour
                    forecast_data[ini_time] = data
                end
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_phes_ed,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts_RT),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_phes_ed,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
    end

    return c_sys5_phes_ed
end

function build_c_sys5_pglib(;
    add_forecasts,
    add_single_time_series,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    nodes = nodes5()
    c_sys5_uc = PSY.System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        thermal_pglib_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
    for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_uc))
        for t in 1:2
            ini_time = timestamp(load_timeseries_DA[t][ix])[1]
            forecast_data[ini_time] = load_timeseries_DA[t][ix]
        end
        if add_single_time_series
            PSY.add_time_series!(
                c_sys5_uc,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        else
            if add_forecasts
                PSY.add_time_series!(
                    c_sys5_uc,
                    l,
                    PSY.Deterministic("max_active_power", forecast_data),
                )
            end
        end
    end
    if add_reserves
        reserve_uc = reserve5(PSY.get_components(PSY.ThermalMultiStart, c_sys5_uc))
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[1],
            PSY.get_components(PSY.ThermalMultiStart, c_sys5_uc),
        )
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[2],
            [collect(PSY.get_components(PSY.ThermalMultiStart, c_sys5_uc))[end]],
        )
        PSY.add_service!(
            c_sys5_uc,
            reserve_uc[3],
            PSY.get_components(PSY.ThermalMultiStart, c_sys5_uc),
        )
        for (ix, serv) in enumerate(PSY.get_components(PSY.VariableReserve, c_sys5_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            if add_single_time_series
                PSY.add_time_series!(
                    c_sys5_uc,
                    serv,
                    PSY.SingleTimeSeries("requirement", Reserve_single_ts),
                )
            else
                if add_forecasts
                    PSY.add_time_series!(
                        c_sys5_uc,
                        serv,
                        PSY.Deterministic("requirement", forecast_data),
                    )
                end
            end
        end
    end

    return c_sys5_uc
end

function build_duration_test_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    DA_dur = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  6:00:00",
            "d/m/y  H:M:S",
        ),
    )
    gens_dur = [
        PSY.ThermalStandard(;
            name = "Alta",
            available = true,
            status = true,
            bus = node,
            active_power = 0.40,
            reactive_power = 0.010,
            rating = 0.5,
            prime_mover_type = PSY.PrimeMovers.ST,
            fuel = PSY.ThermalFuels.COAL,
            active_power_limits = (min = 0.3, max = 0.9),
            reactive_power_limits = nothing,
            ramp_limits = nothing,
            time_limits = (up = 4, down = 2),
            operation_cost = ThermalGenerationCost(
                CostCurve(QuadraticCurve(0.0, 14.0, 0.0)),
                0.0,
                4.0,
                2.0,
            ),
            base_power = 100.0,
            time_at_status = 2.0,
        ),
        PSY.ThermalStandard(;
            name = "Park City",
            available = true,
            status = false,
            bus = node,
            active_power = 1.70,
            reactive_power = 0.20,
            rating = 2.2125,
            prime_mover_type = PSY.PrimeMovers.ST,
            fuel = PSY.ThermalFuels.COAL,
            active_power_limits = (min = 0.7, max = 2.2),
            reactive_power_limits = nothing,
            ramp_limits = nothing,
            time_limits = (up = 6, down = 4),
            operation_cost = ThermalGenerationCost(
                CostCurve(QuadraticCurve(0.0, 15.0, 0.0)),
                0.0,
                1.5,
                0.75,
            ),
            base_power = 100.0,
            time_at_status = 3.0,
        ),
    ]

    duration_load = [0.3, 0.6, 0.8, 0.7, 1.7, 0.9, 0.7]
    load_data = SortedDict(DA_dur[1] => TimeSeries.TimeArray(DA_dur, duration_load))
    load_forecast_dur = PSY.Deterministic("max_active_power", load_data)
    duration_test_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(duration_test_sys, node)
    PSY.add_component!(duration_test_sys, load)
    PSY.add_component!(duration_test_sys, gens_dur[1])
    PSY.add_component!(duration_test_sys, gens_dur[2])
    PSY.add_time_series!(duration_test_sys, load, load_forecast_dur)

    return duration_test_sys
end

function build_5_bus_matpower_DA(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    data_dir = dirname(dirname(raw_data))
    pm_data = PowerSystems.PowerModelsData(raw_data)

    FORECASTS_DIR = joinpath(data_dir, "5-Bus", "5bus_ts", "7day")

    tsp = IS.read_time_series_file_metadata(
        joinpath(FORECASTS_DIR, "timeseries_pointers_da_7day.json"),
    )

    sys = System(pm_data; sys_kwargs...)
    reserves = [
        VariableReserve{ReserveUp}("REG1", true, 5.0, 0.1),
        VariableReserve{ReserveUp}("REG2", true, 5.0, 0.06),
        VariableReserve{ReserveUp}("REG3", true, 5.0, 0.03),
        VariableReserve{ReserveUp}("REG4", true, 5.0, 0.02),
    ]
    contributing_devices = get_components(Generator, sys)
    for r in reserves
        add_service!(sys, r, contributing_devices)
    end

    add_time_series!(sys, tsp)
    transform_single_time_series!(sys, Hour(48), Hour(24))

    return sys
end

function build_5_bus_matpower_RT(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    data_dir = dirname(dirname(raw_data))

    FORECASTS_DIR = joinpath(data_dir, "5-Bus", "5bus_ts", "7day")

    tsp = IS.read_time_series_file_metadata(
        joinpath(FORECASTS_DIR, "timeseries_pointers_rt_7day.json"),
    )

    sys = System(raw_data; sys_kwargs...)

    add_time_series!(sys, tsp)
    transform_single_time_series!(sys, Hour(12), Hour(1))

    return sys
end

function build_5_bus_matpower_AGC(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    data_dir = dirname(dirname(raw_data))
    pm_data = PowerSystems.PowerModelsData(raw_data)

    FORECASTS_DIR = joinpath(data_dir, "5-Bus", "5bus_ts", "7day")

    tsp = IS.read_time_series_file_metadata(
        joinpath(FORECASTS_DIR, "timeseries_pointers_agc_7day.json"),
    )

    sys = System(pm_data; sys_kwargs...)

    add_time_series!(sys, tsp)
    return sys
end

function build_test_RTS_GMLC_sys(; raw_data, add_forecasts, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    if add_forecasts
        rawsys = PSY.PowerSystemTableData(
            raw_data,
            100.0,
            joinpath(raw_data, "user_descriptors.yaml");
            timeseries_metadata_file = joinpath(raw_data, "timeseries_pointers.json"),
            generator_mapping_file = joinpath(raw_data, "generator_mapping.yaml"),
        )
        sys = PSY.System(rawsys; time_series_resolution = Dates.Hour(1), sys_kwargs...)
        PSY.transform_single_time_series!(sys, Hour(24), Dates.Hour(24))
        return sys
    else
        rawsys = PSY.PowerSystemTableData(
            raw_data,
            100.0,
            joinpath(raw_data, "user_descriptors.yaml");
            generator_mapping_file = joinpath(raw_data, "generator_mapping.yaml"),
        )
        sys = PSY.System(rawsys; time_series_resolution = Dates.Hour(1), sys_kwargs...)
        return sys
    end
end

function build_test_RTS_GMLC_sys_with_hybrid(; raw_data, add_forecasts, kwargs...)
    sys = build_test_RTS_GMLC_sys(; raw_data, add_forecasts, kwargs...)
    thermal_unit = first(get_components(ThermalStandard, sys))
    bus = get_bus(thermal_unit)
    electric_load = first(get_components(PowerLoad, sys))
    storage = first(get_components(EnergyReservoirStorage, sys))
    renewable_unit = first(get_components(RenewableDispatch, sys))

    name = "Test H"
    h_sys = HybridSystem(;
        name = name,
        available = true,
        status = true,
        bus = bus,
        active_power = 1.0,
        reactive_power = 1.0,
        thermal_unit = thermal_unit,
        electric_load = electric_load,
        storage = storage,
        renewable_unit = renewable_unit,
        base_power = 100.0,
        operation_cost = MarketBidCost(nothing),
    )
    add_component!(sys, h_sys)
    return sys
end

function build_c_sys5_bat_ems(;
    add_forecasts,
    add_reserves,
    raw_data,
    sys_kwargs...,
)
    time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true)
    nodes = nodes5()
    c_sys5_bat = System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes),
        batteryems5(nodes);
        time_series_in_memory = time_series_in_memory,
    )

    if add_forecasts
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_bat,
                l,
                Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_bat,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
        for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_bat,
                r,
                Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_bat,
                r,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
        for (ix, r) in enumerate(get_components(PSY.EnergyReservoirStorage, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(storage_target_DA[t][1])[1]
                forecast_data[ini_time] = storage_target_DA[t][1]
            end
            add_time_series!(c_sys5_bat, r, Deterministic("storage_target", forecast_data))
            PSY.add_time_series!(
                c_sys5_bat,
                r,
                PSY.SingleTimeSeries("storage_target", storage_target_single_ts_DA),
            )
        end
    end
    if add_reserves
        reserve_bat = reserve5_re(get_components(RenewableDispatch, c_sys5_bat))
        add_service!(
            c_sys5_bat,
            reserve_bat[1],
            get_components(PSY.EnergyReservoirStorage, c_sys5_bat),
        )
        add_service!(
            c_sys5_bat,
            reserve_bat[2],
            get_components(PSY.EnergyReservoirStorage, c_sys5_bat),
        )
        # ORDC
        add_service!(
            c_sys5_bat,
            reserve_bat[3],
            get_components(PSY.EnergyReservoirStorage, c_sys5_bat),
        )
        for (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            add_time_series!(c_sys5_bat, serv, Deterministic("requirement", forecast_data))
            PSY.add_time_series!(
                c_sys5_bat,
                serv,
                PSY.SingleTimeSeries("requirement", Reserve_single_ts),
            )
        end
        for (ix, serv) in enumerate(get_components(ReserveDemandCurve, c_sys5_bat))
            set_variable_cost!(
                c_sys5_bat,
                serv,
                ORDC_cost,
            )
        end
    end

    return c_sys5_bat
end

function build_c_sys5_pglib_sim(; add_forecasts, add_reserves, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    c_sys5_uc = System(
        100.0,
        nodes,
        thermal_pglib_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
    )

    if add_forecasts
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_uc))
            data = vcat(load_timeseries_DA[1][ix] .* 0.3, load_timeseries_DA[2][ix] .* 0.3)
            add_time_series!(c_sys5_uc, l, SingleTimeSeries("max_active_power", data))
        end
        for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_uc))
            data = vcat(ren_timeseries_DA[1][ix], ren_timeseries_DA[2][ix])
            add_time_series!(c_sys5_uc, r, SingleTimeSeries("max_active_power", data))
        end
    end
    if add_reserves
        reserve_uc = reserve5(get_components(ThermalMultiStart, c_sys5_uc))
        add_service!(c_sys5_uc, reserve_uc[1], get_components(ThermalMultiStart, c_sys5_uc))
        add_service!(
            c_sys5_uc,
            reserve_uc[2],
            [collect(get_components(ThermalMultiStart, c_sys5_uc))[end]],
        )
        add_service!(c_sys5_uc, reserve_uc[3], get_components(ThermalMultiStart, c_sys5_uc))
        for serv in get_components(VariableReserve, c_sys5_uc)
            data = vcat(Reserve_ts[1], Reserve_ts[2])
            add_time_series!(c_sys5_uc, serv, SingleTimeSeries("requirement", data))
        end
    end
    PSY.transform_single_time_series!(c_sys5_uc, Hour(24), Dates.Hour(14))
    return c_sys5_uc
end

function build_c_sys5_hybrid(; add_forecasts, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    thermals = thermal_generators5(nodes)
    loads = loads5(nodes)
    renewables = renewable_generators5(nodes)
    _battery(nodes, bus, name) = PSY.EnergyReservoirStorage(;
        name = name,
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        available = true,
        bus = nodes[bus],
        storage_capacity = 7.0,
        storage_level_limits = (min = 0.10 / 7.0, max = 7.0 / 7.0),
        initial_storage_capacity_level = 5.0 / 7.0,
        rating = 7.0,
        active_power = 2.0,
        input_active_power_limits = (min = 0.0, max = 2.0),
        output_active_power_limits = (min = 0.0, max = 2.0),
        efficiency = (in = 0.80, out = 0.90),
        reactive_power = 0.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
        storage_target = 0.2,
        operation_cost = PSY.StorageCost(;
            charge_variable_cost = zero(CostCurve),
            discharge_variable_cost = zero(CostCurve),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 50.0,
            energy_surplus_cost = 40.0,
        ),
    )
    hyd = [
        HybridSystem(;
            name = "RE+battery",
            available = true,
            status = true,
            bus = nodes[1],
            active_power = 6.0,
            reactive_power = 1.0,
            thermal_unit = nothing,
            electric_load = nothing,
            storage = _battery(nodes, 1, "batt_hybrid_1"),
            renewable_unit = renewables[1],
            base_power = 100.0,
            interconnection_rating = 5.0,
            interconnection_impedance = Complex(0.1),
            input_active_power_limits = (min = 0.0, max = 5.0),
            output_active_power_limits = (min = 0.0, max = 5.0),
            reactive_power_limits = (min = 0.0, max = 1.0),
        ),
        HybridSystem(;
            name = "thermal+battery",
            available = true,
            status = true,
            bus = nodes[3],
            active_power = 9.0,
            reactive_power = 1.0,
            thermal_unit = thermals[3],
            electric_load = nothing,
            storage = _battery(nodes, 3, "batt_hybrid_2"),
            renewable_unit = nothing,
            base_power = 100.0,
            interconnection_rating = 10.0,
            interconnection_impedance = Complex(0.1),
            input_active_power_limits = (min = 0.0, max = 10.0),
            output_active_power_limits = (min = 0.0, max = 10.0),
            reactive_power_limits = (min = 0.0, max = 1.0),
        ),
        HybridSystem(;
            name = "load+battery",
            available = true,
            status = true,
            bus = nodes[3],
            active_power = 9.0,
            reactive_power = 1.0,
            electric_load = loads[2],
            storage = _battery(nodes, 3, "batt_hybrid_3"),
            renewable_unit = nothing,
            base_power = 100.0,
            interconnection_rating = 10.0,
            interconnection_impedance = Complex(0.1),
            input_active_power_limits = (min = 0.0, max = 10.0),
            output_active_power_limits = (min = 0.0, max = 10.0),
            reactive_power_limits = (min = 0.0, max = 1.0),
        ),
        HybridSystem(;
            name = "all_hybrid",
            available = true,
            status = true,
            bus = nodes[4],
            active_power = 9.0,
            reactive_power = 1.0,
            electric_load = loads[3],
            thermal_unit = thermals[4],
            storage = _battery(nodes, 4, "batt_hybrid_4"),
            renewable_unit = renewables[2],
            base_power = 100.0,
            interconnection_rating = 15.0,
            interconnection_impedance = Complex(0.1),
            input_active_power_limits = (min = 0.0, max = 15.0),
            output_active_power_limits = (min = 0.0, max = 15.0),
            reactive_power_limits = (min = 0.0, max = 1.0),
        ),
    ]
    c_sys5_hybrid = PSY.System(
        100.0,
        nodes,
        loads[1:1],
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for d in hyd
        PSY.add_component!(c_sys5_hybrid, d)
        set_operation_cost!(d, MarketBidCost(nothing))
    end

    if add_forecasts
        for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hybrid))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hybrid,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_hybrid,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
        _load_devices = filter!(
            x -> !isnothing(PSY.get_electric_load(x)),
            collect(PSY.get_components(PSY.HybridSystem, c_sys5_hybrid)),
        )
        for (ix, hy) in enumerate(_load_devices)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hybrid,
                PSY.get_electric_load(hy),
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_hybrid,
                PSY.get_electric_load(hy),
                PSY.SingleTimeSeries("max_active_power", load_single_timeseries_DA[ix]),
            )
            PSY.copy_subcomponent_time_series!(hy, PSY.get_electric_load(hy))
        end
        _re_devices = filter!(
            x -> !isnothing(PSY.get_renewable_unit(x)),
            collect(PSY.get_components(PSY.HybridSystem, c_sys5_hybrid)),
        )
        for (ix, hy) in enumerate(_re_devices)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            PSY.add_time_series!(
                c_sys5_hybrid,
                PSY.get_renewable_unit(hy),
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_hybrid,
                PSY.get_renewable_unit(hy),
                PSY.SingleTimeSeries("max_active_power", ren_single_timeseries_DA[ix]),
            )
            PSY.copy_subcomponent_time_series!(hy, PSY.get_renewable_unit(hy))
        end
        for (ix, h) in enumerate(PSY.get_components(PSY.HybridSystem, c_sys5_hybrid))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(hybrid_cost_ts[t])[1]
                forecast_data[ini_time] = hybrid_cost_ts[t]
            end
            set_variable_cost!(
                c_sys5_hybrid,
                h,
                PSY.Deterministic("variable_cost", forecast_data),
            )
            set_variable_cost!(
                c_sys5_hybrid,
                h,
                PSY.SingleTimeSeries("variable_cost", hybrid_cost_single_ts),
            )
        end
    end

    return c_sys5_hybrid
end

function build_c_sys5_hybrid_uc(; add_forecasts, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    thermals = thermal_generators5(nodes)
    loads = loads5(nodes)
    renewables = renewable_generators5(nodes)
    branches = branches5(nodes)
    _battery(nodes, bus, name) = PSY.EnergyReservoirStorage(;
        name = name,
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        available = true,
        bus = nodes[bus],
        storage_capacity = 7.0,
        storage_level_limits = (min = 0.10 / 7.0, max = 7.0 / 7.0),
        initial_storage_capacity_level = 5.0 / 7.0,
        rating = 7.0,
        active_power = 2.0,
        input_active_power_limits = (min = 0.0, max = 2.0),
        output_active_power_limits = (min = 0.0, max = 2.0),
        efficiency = (in = 0.80, out = 0.90),
        reactive_power = 0.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
        storage_target = 0.2,
        operation_cost = PSY.StorageCost(;
            charge_variable_cost = zero(CostCurve),
            discharge_variable_cost = zero(CostCurve),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 50.0,
            energy_surplus_cost = 40.0,
        ),
    )
    hyd = [
        HybridSystem(;
            name = "RE+battery",
            available = true,
            status = true,
            bus = nodes[1],
            active_power = 6.0,
            reactive_power = 1.0,
            thermal_unit = nothing,
            electric_load = nothing,
            storage = _battery(nodes, 1, "batt_hybrid_1"),
            renewable_unit = renewables[1],
            base_power = 100.0,
            interconnection_rating = 5.0,
            interconnection_impedance = Complex(0.1),
            input_active_power_limits = (min = 0.0, max = 5.0),
            output_active_power_limits = (min = 0.0, max = 5.0),
            reactive_power_limits = (min = 0.0, max = 1.0),
        ),
    ]

    c_sys5_hybrid = PSY.System(
        100.0,
        nodes,
        thermals,
        renewables,
        loads,
        branches;
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for d in hyd
        PSY.add_component!(c_sys5_hybrid, d)
        set_operation_cost!(d, MarketBidCost(nothing))
    end

    if add_forecasts
        for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hybrid))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hybrid,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_hybrid,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
        for (ix, re) in enumerate(PSY.get_components(PSY.RenewableDispatch, c_sys5_hybrid))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hybrid,
                re,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_hybrid,
                re,
                PSY.SingleTimeSeries("max_active_power", ren_single_timeseries_DA[ix]),
            )
        end
        _re_devices = filter!(
            x -> !isnothing(PSY.get_renewable_unit(x)),
            collect(PSY.get_components(PSY.HybridSystem, c_sys5_hybrid)),
        )
        for (ix, hy) in enumerate(_re_devices)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            PSY.add_time_series!(
                c_sys5_hybrid,
                hy,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_hybrid,
                hy,
                PSY.SingleTimeSeries("max_active_power", ren_single_timeseries_DA[ix]),
            )
            #PSY.copy_subcomponent_time_series!(hy, PSY.get_renewable_unit(hy))
        end
        for (ix, h) in enumerate(PSY.get_components(PSY.HybridSystem, c_sys5_hybrid))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(hybrid_cost_ts[t])[1]
                forecast_data[ini_time] = hybrid_cost_ts[t]
            end
            set_variable_cost!(
                c_sys5_hybrid,
                h,
                PSY.Deterministic("variable_cost", forecast_data),
            )
            set_variable_cost!(
                c_sys5_hybrid,
                h,
                PSY.SingleTimeSeries("variable_cost", hybrid_cost_single_ts),
            )
        end
    end

    return c_sys5_hybrid
end

function build_c_sys5_hybrid_ed(; add_forecasts, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes = nodes5()
    thermals = thermal_generators5(nodes)
    loads = loads5(nodes)
    branches = branches5(nodes)
    renewables = renewable_generators5(nodes)
    _battery(nodes, bus, name) = PSY.EnergyReservoirStorage(;
        name = name,
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        available = true,
        bus = nodes[bus],
        storage_capacity = 7.0,
        storage_level_limits = (min = 0.10 / 7.0, max = 7.0 / 7.0),
        initial_storage_capacity_level = 5.0 / 7.0,
        rating = 7.0,
        active_power = 2.0,
        input_active_power_limits = (min = 0.0, max = 2.0),
        output_active_power_limits = (min = 0.0, max = 2.0),
        efficiency = (in = 0.80, out = 0.90),
        reactive_power = 0.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
        storage_target = 0.2,
        operation_cost = PSY.StorageCost(;
            charge_variable_cost = zero(CostCurve),
            discharge_variable_cost = zero(CostCurve),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 50.0,
            energy_surplus_cost = 40.0,
        ),
    )
    hyd = [
        HybridSystem(;
            name = "RE+battery",
            available = true,
            status = true,
            bus = nodes[1],
            active_power = 6.0,
            reactive_power = 1.0,
            thermal_unit = nothing,
            electric_load = nothing,
            storage = _battery(nodes, 1, "batt_hybrid_1"),
            renewable_unit = renewables[1],
            base_power = 100.0,
            interconnection_rating = 5.0,
            interconnection_impedance = Complex(0.1),
            input_active_power_limits = (min = 0.0, max = 5.0),
            output_active_power_limits = (min = 0.0, max = 5.0),
            reactive_power_limits = (min = 0.0, max = 1.0),
        ),
    ]

    c_sys5_hybrid = PSY.System(
        100.0,
        nodes,
        thermals,
        renewables,
        loads,
        branches;
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )

    for d in hyd
        PSY.add_component!(c_sys5_hybrid, d)
        set_operation_cost!(d, MarketBidCost(nothing))
    end

    if add_forecasts
        for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_hybrid))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2 # loop over days
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta) # loop over hours
                    ini_time = timestamp(ta[i]) #get the hour
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                    forecast_data[ini_time[1]] = data
                end
            end
            PSY.add_time_series!(
                c_sys5_hybrid,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_hybrid,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
        for (ix, l) in enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_hybrid))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ta = ren_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(ren_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            PSY.add_time_series!(
                c_sys5_hybrid,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_hybrid,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
        _re_devices = filter!(
            x -> !isnothing(PSY.get_renewable_unit(x)),
            collect(PSY.get_components(PSY.HybridSystem, c_sys5_hybrid)),
        )
        for (ix, hy) in enumerate(_re_devices)
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ta = ren_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(ren_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            #applying a patch for the time being with "hy"
            PSY.add_time_series!(
                c_sys5_hybrid,
                hy,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_hybrid,
                hy,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_RT[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
            #PSY.copy_subcomponent_time_series!(hy, PSY.get_renewable_unit(hy))
        end
        for (ix, h) in enumerate(PSY.get_components(PSY.HybridSystem, c_sys5_hybrid))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ta = hybrid_cost_ts[t]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(hybrid_cost_ts_RT[t][1], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            set_variable_cost!(
                c_sys5_hybrid,
                h,
                PSY.Deterministic("variable_cost", forecast_data),
            )
        end
    end

    return c_sys5_hybrid
end

function build_hydro_test_case_b_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  2:00:00",
            "d/m/y  H:M:S",
        ),
    )

    hydro, reservoir = _get_generic_hydro_reservoir_pair(node)
    duration_load = [0.3, 0.6, 0.5]
    load_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, duration_load))
    load_forecast_dur = PSY.Deterministic("max_active_power", load_data)

    inflow = [0.5, 0.5, 0.5]
    inflow_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, inflow))
    inflow_forecast_dur = PSY.Deterministic("inflow", inflow_data)

    energy_target = [0.0, 0.0, 0.1]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast_dur = PSY.Deterministic("storage_target", energy_target_data)

    hydro_test_case_b_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(hydro_test_case_b_sys, node)
    PSY.add_component!(hydro_test_case_b_sys, load)
    PSY.add_component!(hydro_test_case_b_sys, hydro)
    PSY.add_component!(hydro_test_case_b_sys, reservoir)
    PSY.set_downstream_turbines!(reservoir, [hydro])
    PSY.add_time_series!(hydro_test_case_b_sys, load, load_forecast_dur)
    PSY.add_time_series!(hydro_test_case_b_sys, reservoir, inflow_forecast_dur)
    PSY.add_time_series!(hydro_test_case_b_sys, reservoir, energy_target_forecast_dur)

    return hydro_test_case_b_sys
end

function build_hydro_test_case_c_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  2:00:00",
            "d/m/y  H:M:S",
        ),
    )
    turbine, reservoir = _get_generic_hydro_reservoir_pair(node)
    set_downstream_turbines!(reservoir, [turbine])

    duration_load = [0.3, 0.6, 0.5]
    load_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, duration_load))
    load_forecast_dur = PSY.Deterministic("max_active_power", load_data)

    inflow = [0.5, 0.5, 0.5]
    inflow_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, inflow))
    inflow_forecast_dur = PSY.Deterministic("inflow", inflow_data)

    energy_target = [0.0, 0.0, 0.1]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast_dur = PSY.Deterministic("storage_target", energy_target_data)

    hydro_test_case_c_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(hydro_test_case_c_sys, node)
    PSY.add_component!(hydro_test_case_c_sys, load)
    PSY.add_component!(hydro_test_case_c_sys, turbine)
    PSY.add_component!(hydro_test_case_c_sys, reservoir)
    PSY.add_time_series!(hydro_test_case_c_sys, load, load_forecast_dur)
    PSY.add_time_series!(hydro_test_case_c_sys, reservoir, inflow_forecast_dur)
    PSY.add_time_series!(hydro_test_case_c_sys, reservoir, energy_target_forecast_dur)

    return hydro_test_case_c_sys
end

function build_hydro_test_case_d_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  2:00:00",
            "d/m/y  H:M:S",
        ),
    )
    turbine, reservoir = _get_generic_hydro_reservoir_pair(node)
    set_downstream_turbines!(reservoir, [turbine])
    duration_load = [0.3, 0.6, 0.5]
    load_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, duration_load))
    load_forecast_dur = PSY.Deterministic("max_active_power", load_data)

    inflow = [0.5, 0.5, 0.5]
    inflow_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, inflow))
    inflow_forecast_dur = PSY.Deterministic("inflow", inflow_data)

    energy_target = [0.0, 0.0, 0.0]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast_dur = PSY.Deterministic("storage_target", energy_target_data)

    hydro_test_case_d_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(hydro_test_case_d_sys, node)
    PSY.add_component!(hydro_test_case_d_sys, load)
    PSY.add_component!(hydro_test_case_d_sys, turbine)
    PSY.add_component!(hydro_test_case_d_sys, reservoir)
    PSY.add_time_series!(hydro_test_case_d_sys, load, load_forecast_dur)
    PSY.add_time_series!(hydro_test_case_d_sys, reservoir, inflow_forecast_dur)
    PSY.add_time_series!(hydro_test_case_d_sys, reservoir, energy_target_forecast_dur)

    return hydro_test_case_d_sys
end

function build_hydro_test_case_e_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  2:00:00",
            "d/m/y  H:M:S",
        ),
    )
    turbine, reservoir = _get_generic_hydro_reservoir_pair(node)
    set_downstream_turbines!(reservoir, [turbine])
    duration_load = [0.3, 0.6, 0.5]
    load_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, duration_load))
    load_forecast_dur = PSY.Deterministic("max_active_power", load_data)

    inflow = [0.5, 0.5, 0.5]
    inflow_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, inflow))
    inflow_forecast_dur = PSY.Deterministic("inflow", inflow_data)

    energy_target = [0.2, 0.2, 0.0]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast_dur = PSY.Deterministic("storage_target", energy_target_data)

    hydro_test_case_e_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(hydro_test_case_e_sys, node)
    PSY.add_component!(hydro_test_case_e_sys, load)
    PSY.add_component!(hydro_test_case_e_sys, turbine)
    PSY.add_component!(hydro_test_case_e_sys, reservoir)
    PSY.add_time_series!(hydro_test_case_e_sys, load, load_forecast_dur)
    PSY.add_time_series!(hydro_test_case_e_sys, reservoir, inflow_forecast_dur)
    PSY.add_time_series!(hydro_test_case_e_sys, reservoir, energy_target_forecast_dur)

    return hydro_test_case_e_sys
end

function build_hydro_test_case_f_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  2:00:00",
            "d/m/y  H:M:S",
        ),
    )
    turbine, reservoir = _get_generic_hydro_reservoir_pair(node)
    set_downstream_turbines!(reservoir, [turbine])
    duration_load = [0.3, 0.6, 0.5]
    load_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, duration_load))
    load_forecast_dur = PSY.Deterministic("max_active_power", load_data)

    inflow = [0.5, 0.5, 0.5]
    inflow_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, inflow))
    inflow_forecast_dur = PSY.Deterministic("inflow", inflow_data)

    energy_target = [0.0, 0.0, 0.1]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast_dur = PSY.Deterministic("storage_target", energy_target_data)

    hydro_test_case_f_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(hydro_test_case_f_sys, node)
    PSY.add_component!(hydro_test_case_f_sys, load)
    PSY.add_component!(hydro_test_case_f_sys, turbine)
    PSY.add_component!(hydro_test_case_f_sys, reservoir)
    PSY.add_time_series!(hydro_test_case_f_sys, load, load_forecast_dur)
    PSY.add_time_series!(hydro_test_case_f_sys, reservoir, inflow_forecast_dur)
    PSY.add_time_series!(hydro_test_case_f_sys, reservoir, energy_target_forecast_dur)

    return hydro_test_case_f_sys
end

function build_batt_test_case_b_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  2:00:00",
            "d/m/y  H:M:S",
        ),
    )
    re = RenewableDispatch(
        "WindBusC",
        true,
        node,
        0.0,
        0.0,
        1.20,
        PrimeMovers.WT,
        (min = -0.800, max = 0.800),
        1.0,
        RenewableGenerationCost(CostCurve(LinearCurve(0.220))),
        100.0,
    )

    batt = PSY.EnergyReservoirStorage(;
        name = "Bat2",
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        available = true,
        bus = node,
        storage_capacity = 7.0,
        storage_level_limits = (min = 0.10 / 7.0, max = 7.0 / 7.0),
        initial_storage_capacity_level = 5.0 / 7.0,
        rating = 7.0,
        active_power = 2.0,
        input_active_power_limits = (min = 0.0, max = 2.0),
        output_active_power_limits = (min = 0.0, max = 2.0),
        efficiency = (in = 0.80, out = 0.90),
        reactive_power = 0.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
        storage_target = 0.2,
        operation_cost = PSY.StorageCost(;
            charge_variable_cost = zero(CostCurve),
            discharge_variable_cost = zero(CostCurve),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 0.001,
            energy_surplus_cost = 10.0,
        ),
    )
    load_ts = [0.3, 0.6, 0.5]
    load_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, load_ts))
    load_forecast = PSY.Deterministic("max_active_power", load_data)

    wind_ts = [0.5, 0.7, 0.8]
    wind_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, wind_ts))
    wind_forecast = PSY.Deterministic("max_active_power", wind_data)

    energy_target = [0.4, 0.4, 0.1]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast = PSY.Deterministic("storage_target", energy_target_data)

    batt_test_case_b_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(batt_test_case_b_sys, node)
    PSY.add_component!(batt_test_case_b_sys, load)
    PSY.add_component!(batt_test_case_b_sys, re)
    PSY.add_component!(batt_test_case_b_sys, batt)
    PSY.add_time_series!(batt_test_case_b_sys, load, load_forecast)
    PSY.add_time_series!(batt_test_case_b_sys, re, wind_forecast)
    PSY.add_time_series!(batt_test_case_b_sys, batt, energy_target_forecast)

    return batt_test_case_b_sys
end

function build_batt_test_case_c_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  2:00:00",
            "d/m/y  H:M:S",
        ),
    )
    re = RenewableDispatch(
        "WindBusC",
        true,
        node,
        0.0,
        0.0,
        1.20,
        PrimeMovers.WT,
        (min = -0.800, max = 0.800),
        1.0,
        RenewableGenerationCost(CostCurve(LinearCurve(0.220))),
        100.0,
    )

    batt = PSY.EnergyReservoirStorage(;
        name = "Bat2",
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        available = true,
        bus = node,
        storage_capacity = 7.0,
        storage_level_limits = (min = 0.10 / 7.0, max = 7.0 / 7.0),
        initial_storage_capacity_level = 2.0 / 7.0,
        rating = 7.0,
        active_power = 2.0,
        input_active_power_limits = (min = 0.0, max = 2.0),
        output_active_power_limits = (min = 0.0, max = 2.0),
        efficiency = (in = 0.80, out = 0.90),
        reactive_power = 0.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
        storage_target = 0.2,
        operation_cost = PSY.StorageCost(;
            charge_variable_cost = zero(CostCurve),
            discharge_variable_cost = zero(CostCurve),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 50.0,
            energy_surplus_cost = 0.0,
        ),
    )
    load_ts = [0.3, 0.6, 0.5]
    load_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, load_ts))
    load_forecast = PSY.Deterministic("max_active_power", load_data)

    wind_ts = [0.9, 0.7, 0.8]
    wind_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, wind_ts))
    wind_forecast = PSY.Deterministic("max_active_power", wind_data)

    energy_target = [0.0, 0.0, 0.4]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast = PSY.Deterministic("storage_target", energy_target_data)

    batt_test_case_c_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(batt_test_case_c_sys, node)
    PSY.add_component!(batt_test_case_c_sys, load)
    PSY.add_component!(batt_test_case_c_sys, re)
    PSY.add_component!(batt_test_case_c_sys, batt)
    PSY.add_time_series!(batt_test_case_c_sys, load, load_forecast)
    PSY.add_time_series!(batt_test_case_c_sys, re, wind_forecast)
    PSY.add_time_series!(batt_test_case_c_sys, batt, energy_target_forecast)

    return batt_test_case_c_sys
end

function build_batt_test_case_d_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  3:00:00",
            "d/m/y  H:M:S",
        ),
    )
    re = RenewableDispatch(
        "WindBusC",
        true,
        node,
        0.0,
        0.0,
        1.20,
        PrimeMovers.WT,
        (min = -0.800, max = 0.800),
        1.0,
        RenewableGenerationCost(CostCurve(LinearCurve(0.220))),
        100.0,
    )

    batt = PSY.EnergyReservoirStorage(;
        name = "Bat2",
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        available = true,
        bus = node,
        storage_capacity = 7.0,
        storage_level_limits = (min = 0.10 / 7.0, max = 7.0 / 7.0),
        initial_storage_capacity_level = 2.0 / 7.0,
        rating = 7.0,
        active_power = 2.0,
        input_active_power_limits = (min = 0.0, max = 2.0),
        output_active_power_limits = (min = 0.0, max = 2.0),
        efficiency = (in = 0.80, out = 0.90),
        reactive_power = 0.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
        storage_target = 0.2,
        operation_cost = PSY.StorageCost(;
            charge_variable_cost = zero(CostCurve),
            discharge_variable_cost = zero(CostCurve),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 0.0,
            energy_surplus_cost = -10.0,
        ),
    )
    load_ts = [0.3, 0.6, 0.5, 0.8]
    load_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, load_ts))
    load_forecast = PSY.Deterministic("max_active_power", load_data)

    wind_ts = [0.9, 0.7, 0.8, 0.1]
    wind_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, wind_ts))
    wind_forecast = PSY.Deterministic("max_active_power", wind_data)

    energy_target = [0.0, 0.0, 0.0, 0.0]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast = PSY.Deterministic("storage_target", energy_target_data)

    batt_test_case_d_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(batt_test_case_d_sys, node)
    PSY.add_component!(batt_test_case_d_sys, load)
    PSY.add_component!(batt_test_case_d_sys, re)
    PSY.add_component!(batt_test_case_d_sys, batt)
    PSY.add_time_series!(batt_test_case_d_sys, load, load_forecast)
    PSY.add_time_series!(batt_test_case_d_sys, re, wind_forecast)
    PSY.add_time_series!(batt_test_case_d_sys, batt, energy_target_forecast)

    return batt_test_case_d_sys
end

function build_batt_test_case_e_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  2:00:00",
            "d/m/y  H:M:S",
        ),
    )
    re = RenewableDispatch(
        "WindBusC",
        true,
        node,
        0.0,
        0.0,
        1.20,
        PrimeMovers.WT,
        (min = -0.800, max = 0.800),
        1.0,
        RenewableGenerationCost(CostCurve(LinearCurve(0.220))),
        100.0,
    )

    batt = PSY.EnergyReservoirStorage(;
        name = "Bat2",
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        available = true,
        bus = node,
        storage_capacity = 7.0,
        storage_level_limits = (min = 0.10 / 7.0, max = 7.0 / 7.0),
        initial_storage_capacity_level = 2.0 / 7.0,
        rating = 7.0,
        active_power = 2.0,
        input_active_power_limits = (min = 0.0, max = 2.0),
        output_active_power_limits = (min = 0.0, max = 2.0),
        efficiency = (in = 0.80, out = 0.90),
        reactive_power = 0.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
        storage_target = 0.2,
        operation_cost = PSY.StorageCost(;
            charge_variable_cost = zero(CostCurve),
            discharge_variable_cost = zero(CostCurve),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 50.0,
            energy_surplus_cost = 50.0,
        ),
    )
    load_ts = [0.3, 0.6, 0.5]
    load_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, load_ts))
    load_forecast = PSY.Deterministic("max_active_power", load_data)

    wind_ts = [0.9, 0.7, 0.8]
    wind_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, wind_ts))
    wind_forecast = PSY.Deterministic("max_active_power", wind_data)

    energy_target = [0.2, 0.2, 0.0]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast = PSY.Deterministic("storage_target", energy_target_data)

    batt_test_case_e_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(batt_test_case_e_sys, node)
    PSY.add_component!(batt_test_case_e_sys, load)
    PSY.add_component!(batt_test_case_e_sys, re)
    PSY.add_component!(batt_test_case_e_sys, batt)
    PSY.add_time_series!(batt_test_case_e_sys, load, load_forecast)
    PSY.add_time_series!(batt_test_case_e_sys, re, wind_forecast)
    PSY.add_time_series!(batt_test_case_e_sys, batt, energy_target_forecast)

    return batt_test_case_e_sys
end

function build_batt_test_case_f_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.2, 0.9861, 100.0, 1.0, 2.0)
    time_periods = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  2:00:00",
            "d/m/y  H:M:S",
        ),
    )
    re = RenewableDispatch(
        "WindBusC",
        true,
        node,
        0.0,
        0.0,
        1.20,
        PrimeMovers.WT,
        (min = -0.800, max = 0.800),
        1.0,
        RenewableGenerationCost(CostCurve(LinearCurve(0.220))),
        100.0,
    )

    batt = PSY.EnergyReservoirStorage(;
        name = "Bat2",
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        available = true,
        bus = node,
        storage_capacity = 7.0,
        storage_level_limits = (min = 0.10 / 7.0, max = 7.0 / 7.0),
        initial_storage_capacity_level = 2.0 / 7.0,
        rating = 7.0,
        active_power = 2.0,
        input_active_power_limits = (min = 0.0, max = 2.0),
        output_active_power_limits = (min = 0.0, max = 2.0),
        efficiency = (in = 0.80, out = 0.90),
        reactive_power = 0.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
        storage_target = 0.2,
        operation_cost = PSY.StorageCost(;
            charge_variable_cost = zero(CostCurve),
            discharge_variable_cost = zero(CostCurve),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 50.0,
            energy_surplus_cost = -5.0,
        ),
    )
    load_ts = [0.3, 0.6, 0.5]
    load_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, load_ts))
    load_forecast = PSY.Deterministic("max_active_power", load_data)

    wind_ts = [0.9, 0.7, 0.8]
    wind_data = SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, wind_ts))
    wind_forecast = PSY.Deterministic("max_active_power", wind_data)

    energy_target = [0.0, 0.0, 0.3]
    energy_target_data =
        SortedDict(time_periods[1] => TimeSeries.TimeArray(time_periods, energy_target))
    energy_target_forecast = PSY.Deterministic("storage_target", energy_target_data)

    batt_test_case_f_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(batt_test_case_f_sys, node)
    PSY.add_component!(batt_test_case_f_sys, load)
    PSY.add_component!(batt_test_case_f_sys, re)
    PSY.add_component!(batt_test_case_f_sys, batt)
    PSY.add_time_series!(batt_test_case_f_sys, load, load_forecast)
    PSY.add_time_series!(batt_test_case_f_sys, re, wind_forecast)
    PSY.add_time_series!(batt_test_case_f_sys, batt, energy_target_forecast)

    return batt_test_case_f_sys
end

function build_c_sys5_all_components(; add_forecasts, raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)

    nodes = nodes5()
    hydros = hydro_generators5(nodes)
    reservoir = hydro_reservoir5_energy()
    c_sys5_all_components = PSY.System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        hydros,
        branches5(nodes);
        time_series_in_memory = get(sys_kwargs, :time_series_in_memory, true),
        sys_kwargs...,
    )
    add_component!(c_sys5_all_components, reservoir[1])
    set_downstream_turbines!(reservoir[1], [hydros[2]])

    # TODO refactor as per https://github.com/NREL-Sienna/PowerSystemCaseBuilder.jl/issues/66
    if add_forecasts
        for (ix, l) in enumerate(PSY.get_components(PSY.PowerLoad, c_sys5_all_components))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            PSY.add_time_series!(
                c_sys5_all_components,
                l,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_all_components,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    load_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
        for (ix, h) in
            enumerate(PSY.get_components(PSY.HydroTurbine, c_sys5_all_components))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
            end
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        end
        for (ix, h) in
            enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_all_components))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(storage_target_DA[t][ix])[1]
                forecast_data[ini_time] = storage_target_DA[t][ix]
            end
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.Deterministic("storage_target", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.SingleTimeSeries(
                    "storage_target",
                    storage_target_single_ts_DA;
                    scaling_factor_multiplier = PSY.get_storage_capacity,
                ),
            )
        end
        for (ix, h) in
            enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_all_components))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix] .* 0.8
            end
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.Deterministic("inflow", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.SingleTimeSeries(
                    "inflow",
                    hydro_single_timeseries_DA;
                    scaling_factor_multiplier = PSY.get_storage_capacity,
                ),
            )
        end
        for (ix, h) in
            enumerate(PSY.get_components(PSY.HydroReservoir, c_sys5_all_components))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = TimeSeries.timestamp(hydro_budget_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_budget_DA[t][ix]
            end
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.Deterministic("hydro_budget", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.SingleTimeSeries(
                    "hydro_budget",
                    hydro_budget_single_ts_DA;
                    scaling_factor_multiplier = PSY.get_storage_capacity,
                ),
            )
        end
        for (ix, h) in
            enumerate(PSY.get_components(PSY.HydroDispatch, c_sys5_all_components))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
            end
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_all_components,
                h,
                PSY.SingleTimeSeries("max_active_power", hydro_single_timeseries_DA),
            )
        end
        for (ix, r) in
            enumerate(PSY.get_components(PSY.RenewableGen, c_sys5_all_components))
            forecast_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
            for t in 1:2
                ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            PSY.add_time_series!(
                c_sys5_all_components,
                r,
                PSY.Deterministic("max_active_power", forecast_data),
            )
            PSY.add_time_series!(
                c_sys5_all_components,
                r,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    ren_single_timeseries_DA[ix];
                    scaling_factor_multiplier = PSY.get_max_active_power,
                ),
            )
        end
    end

    bus3 = PSY.get_component(PowerLoad, c_sys5_all_components, "Bus3")
    PSY.convert_component!(c_sys5_all_components, bus3, StandardLoad)
    return c_sys5_all_components
end

function build_c_sys5_radial(; raw_data, kwargs...)
    sys = build_c_sys5_uc(; raw_data, kwargs...)
    new_sys = deepcopy(sys)
    ################################
    #### Create Extension Buses ####
    ################################

    busC = get_component(ACBus, new_sys, "nodeC")

    busC_ext1 = ACBus(;
        number = 301,
        name = "nodeC_ext1",
        available = true,
        bustype = ACBusTypes.PQ,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.9, max = 1.05),
        base_voltage = 230.0,
        area = nothing,
        load_zone = nothing,
    )

    busC_ext2 = ACBus(;
        number = 302,
        name = "nodeC_ext2",
        available = true,
        bustype = ACBusTypes.PQ,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.9, max = 1.05),
        base_voltage = 230.0,
        area = nothing,
        load_zone = nothing,
    )

    add_components!(new_sys, [busC_ext1, busC_ext2])

    ################################
    #### Create Extension Lines ####
    ################################

    line_C_to_ext1 = Line(;
        name = "C_to_ext1",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = Arc(; from = busC, to = busC_ext1),
        #r = 0.00281,
        r = 0.0,
        x = 0.0281,
        b = (from = 0.00356, to = 0.00356),
        rating = 2.0,
        angle_limits = (min = -0.7, max = 0.7),
    )

    line_ext1_to_ext2 = Line(;
        name = "ext1_to_ext2",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = Arc(; from = busC_ext1, to = busC_ext2),
        #r = 0.00281,
        r = 0.0,
        x = 0.0281,
        b = (from = 0.00356, to = 0.00356),
        rating = 2.0,
        angle_limits = (min = -0.7, max = 0.7),
    )

    add_components!(new_sys, [line_C_to_ext1, line_ext1_to_ext2])

    ###################################
    ###### Update Extension Loads #####
    ###################################

    load_bus3 = get_component(PowerLoad, new_sys, "Bus3")

    load_ext1 = PowerLoad(;
        name = "Bus_ext1",
        available = true,
        bus = busC_ext1,
        active_power = 1.0,
        reactive_power = 0.9861 / 3,
        base_power = 100.0,
        max_active_power = 1.0,
        max_reactive_power = 0.9861 / 3,
    )

    load_ext2 = PowerLoad(;
        name = "Bus_ext2",
        available = true,
        bus = busC_ext2,
        active_power = 1.0,
        reactive_power = 0.9861 / 3,
        base_power = 100.0,
        max_active_power = 1.0,
        max_reactive_power = 0.9861 / 3,
    )

    add_components!(new_sys, [load_ext1, load_ext2])

    copy_time_series!(load_ext1, load_bus3)
    copy_time_series!(load_ext2, load_bus3)

    set_active_power!(load_bus3, 1.0)
    set_max_active_power!(load_bus3, 1.0)
    set_reactive_power!(load_bus3, 0.3287)
    set_max_reactive_power!(load_bus3, 0.3287)
    return new_sys
end

function build_two_area_pjm_DA(; add_forecasts, add_reserves, raw_data, sys_kwargs...)
    nodes_area1 = nodes5()
    for n in nodes_area1
        PSY.set_name!(n, "Bus_$(PSY.get_name(n))_1")
        PSY.set_number!(n, 10 + PSY.get_number(n))
    end

    nodes_area2 = nodes5()
    for n in nodes_area2
        PSY.set_name!(n, "Bus_$(PSY.get_name(n))_2")
        PSY.set_number!(n, 20 + PSY.get_number(n))
        if PSY.get_bustype(n) == PSY.ACBusTypes.REF
            set_bustype!(n, PSY.ACBusTypes.PV)
        end
    end

    thermals_1 = thermal_generators5(nodes_area1)
    for n in thermals_1
        PSY.set_name!(n, "$(PSY.get_name(n))_1")
    end

    thermals_2 = thermal_generators5(nodes_area2)
    for n in thermals_2
        PSY.set_name!(n, "$(PSY.get_name(n))_2")
    end

    loads_1 = loads5(nodes_area1)
    for n in loads_1
        PSY.set_name!(n, "$(PSY.get_name(n))_1")
    end

    loads_2 = loads5(nodes_area2)
    for n in loads_2
        PSY.set_name!(n, "$(PSY.get_name(n))_2")
    end

    branches_1 = branches5(nodes_area1)
    for n in branches_1
        PSY.set_name!(n, "$(PSY.get_name(n))_1")
    end

    branches_2 = branches5(nodes_area2)
    for n in branches_2
        PSY.set_name!(n, "$(PSY.get_name(n))_2")
    end

    sys = PSY.System(
        100.0,
        [nodes_area1; nodes_area2],
        [thermals_1; thermals_2],
        [loads_1; loads_2],
        [branches_1; branches_2];
        sys_kwargs...,
    )

    area1 = Area(; name = "Area1")
    area2 = Area(; name = "Area2")

    add_component!(sys, area1)
    add_component!(sys, area2)

    exchange_1_2 = AreaInterchange(;
        name = "1_2",
        available = true,
        active_power_flow = 0.0,
        from_area = area1,
        to_area = area2,
        flow_limits = (from_to = 1.5, to_from = 1.5),
    )

    PSY.add_component!(sys, exchange_1_2)

    inter_area_line = MonitoredLine(;
        name = "inter_area_line",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        rating = 10.0,
        angle_limits = (-1.571, 1.571),
        r = 0.003,
        x = 0.03,
        b = (from = 0.00337, to = 0.00337),
        flow_limits = (from_to = 7.0, to_from = 7.0),
        arc = PSY.Arc(; from = nodes_area1[3], to = nodes_area2[3]),
    )

    PSY.add_component!(sys, inter_area_line)

    for n in nodes_area1
        set_area!(n, area1)
    end

    for n in nodes_area2
        set_area!(n, area2)
    end

    pv_device = PSY.RenewableDispatch(
        "PVBus5",
        true,
        nodes_area1[3],
        0.0,
        0.0,
        3.84,
        PrimeMovers.PVe,
        (min = 0.0, max = 0.0),
        1.0,
        RenewableGenerationCost(nothing),
        100.0,
    )
    wind_device = PSY.RenewableDispatch(
        "WindBus1",
        true,
        nodes_area2[1],
        0.0,
        0.0,
        4.51,
        PrimeMovers.WT,
        (min = 0.0, max = 0.0),
        1.0,
        RenewableGenerationCost(nothing),
        100.0,
    )
    PSY.add_component!(sys, pv_device)
    PSY.add_component!(sys, wind_device)
    timeseries_dataset =
        HDF5.h5read(joinpath(DATA_DIR, "5-Bus", "PJM_5_BUS_7_DAYS.h5"), "Time Series Data")
    refdate = first(DayAhead)
    da_load_time_series = DateTime[]
    da_load_time_series_val = Float64[]

    for i in 1:7
        for v in timeseries_dataset["DA Load Data"]["DA_LOAD_DAY_$(i)"]
            h = refdate + Hour(v.HOUR + (i - 1) * 24)
            push!(da_load_time_series, h)
            push!(da_load_time_series_val, v.LOAD)
        end
    end

    re_timeseries = Dict(
        "PVBus5" => CSV.read(
            joinpath(
                DATA_DIR,
                "5-Bus",
                "5bus_ts",
                "gen",
                "Renewable",
                "PV",
                "da_solar.csv",
            ),
            DataFrame,
        )[
            :,
            :SolarBusC,
        ],
        "WindBus1" => CSV.read(
            joinpath(
                DATA_DIR,
                "5-Bus",
                "5bus_ts",
                "gen",
                "Renewable",
                "WIND",
                "da_wind.csv",
            ),
            DataFrame,
        )[
            :,
            :WindBusA,
        ],
    )
    re_timeseries["WindBus1"] = re_timeseries["WindBus1"] ./ 451

    bus_dist_fact = Dict(
        "Bus2_1" => 0.33,
        "Bus3_1" => 0.33,
        "Bus4_1" => 0.34,
        "Bus2_2" => 0.33,
        "Bus3_2" => 0.33,
        "Bus4_2" => 0.34,
    )
    peak_load = maximum(da_load_time_series_val)
    if add_forecasts
        for (ix, l) in enumerate(PSY.get_components(PowerLoad, sys))
            set_max_active_power!(l, bus_dist_fact[PSY.get_name(l)] * peak_load / 100)
            add_time_series!(
                sys,
                l,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    TimeArray(da_load_time_series, da_load_time_series_val ./ peak_load),
                ),
            )
        end
        for (ix, g) in enumerate(PSY.get_components(RenewableDispatch, sys))
            add_time_series!(
                sys,
                g,
                PSY.SingleTimeSeries(
                    "max_active_power",
                    TimeArray(da_load_time_series, re_timeseries[PSY.get_name(g)]),
                ),
            )
        end
    end
    if add_reserves
        thermal_standard_area_1 = collect(
            PSY.get_components(
                x -> PSY.get_name(PSY.get_area(PSY.get_bus(x))) == "Area1",
                PSY.ThermalStandard,
                sys,
            ),
        )
        thermal_standard_area_2 = collect(
            PSY.get_components(
                x -> PSY.get_name(PSY.get_area(PSY.get_bus(x))) == "Area2",
                PSY.ThermalStandard,
                sys,
            ),
        )
        reserves_area_1 = reserve5(thermal_standard_area_1)
        for reserve in reserves_area_1
            PSY.set_name!(reserve, "$(PSY.get_name(reserve))_1")
        end
        reserves_area_2 = reserve5(thermal_standard_area_2)
        for reserve in reserves_area_2
            PSY.set_name!(reserve, "$(PSY.get_name(reserve))_2")
        end
        for (area_thermals, area_reserves) in zip(
            [thermal_standard_area_1, thermal_standard_area_2],
            [reserves_area_1, reserves_area_2],
        )
            PSY.add_service!(
                sys,
                area_reserves[1],
                area_thermals,
            )
            PSY.add_service!(
                sys,
                area_reserves[2],
                area_thermals[end],
            )
            PSY.add_service!(
                sys,
                area_reserves[3],
                area_thermals,
            )
            # ORDC Curve
            PSY.add_service!(
                sys,
                area_reserves[4],
                area_thermals,
            )
        end
        for serv in PSY.get_components(PSY.VariableReserve, sys)
            reserve_time_series = PSY.SingleTimeSeries(;
                name = "requirement",
                data = TimeSeries.TimeArray(da_load_time_series, rand(168)),
            )
            PSY.add_time_series!(
                sys,
                serv,
                reserve_time_series,
            )
        end
        for (ix, serv) in enumerate(PSY.get_components(PSY.ReserveDemandCurve, sys))
            PSY.set_variable_cost!(
                sys,
                serv,
                ORDC_cost,
            )
        end
    end

    return sys
end

####### Cost Function Testing Systems ################
function _build_cost_base_test_sys(; kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    node =
        PSY.ACBus(
            1,
            "nodeA",
            true,
            "REF",
            0,
            1.0,
            (min = 0.9, max = 1.05),
            230,
            nothing,
            nothing,
        )
    load = PSY.PowerLoad("Bus1", true, node, 0.4, 0.9861, 100.0, 1.0, 2.0)

    gen = ThermalStandard(;
        name = "Cheap Unit",
        available = true,
        status = true,
        bus = node,
        active_power = 1.70,
        reactive_power = 0.20,
        rating = 2.2125,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.0, max = 1.70),
        reactive_power_limits = (min = -1.275, max = 1.275),
        ramp_limits = (up = 0.02 * 2.2125, down = 0.02 * 2.2125),
        time_limits = (up = 2.0, down = 1.0),
        operation_cost = ThermalGenerationCost(CostCurve(LinearCurve(0.23)),
            0.0,
            1.5,
            0.75,
        ),
        base_power = 100.0,
    )

    DA_load_forecast = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
    ini_time = DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S")
    # Load levels to catch each segment in the curves
    load_forecasts = [[2.1, 3.4, 2.76, 3.0, 1.0], [1.3, 3.0, 2.1, 1.0, 1.0]]
    for (ix, date) in enumerate(range(ini_time; length = 2, step = Hour(1)))
        DA_load_forecast[date] =
            TimeSeries.TimeArray(
                range(ini_time; length = 5, step = Hour(1)),
                load_forecasts[ix],
            )
    end
    load_forecast = PSY.Deterministic("max_active_power", DA_load_forecast)
    cost_test_sys = PSY.System(100.0; sys_kwargs...)
    PSY.add_component!(cost_test_sys, node)
    PSY.add_component!(cost_test_sys, load)
    PSY.add_component!(cost_test_sys, gen)
    PSY.add_time_series!(cost_test_sys, load, load_forecast)
    return cost_test_sys
end

function build_linear_cost_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_linear_cost(node)
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

function build_linear_fuel_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_linear_fuel(node)
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

function build_quadratic_cost_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_quad_cost(node)
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

function build_quadratic_fuel_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_quad_fuel(node)
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

function build_pwl_io_cost_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_pwl_io_cost(node)
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

function build_pwl_io_fuel_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_pwl_io_fuel(node)
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

function build_pwl_incremental_cost_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_pwl_incremental_cost(node)
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

function build_pwl_incremental_fuel_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_pwl_incremental_fuel(node)
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

"Same as build_pwl_incremental_cost_test_sys but converts on the fly to PiecewiseAverageCurve"
function build_pwl_average_cost_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_pwl_incremental_cost(node)
    oc = get_operation_cost(test_gen)
    set_variable!(oc, CostCurve(AverageRateCurve(get_value_curve(get_variable(oc)))))
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

"Same as build_pwl_incremental_fuel_test_sys but converts on the fly to PiecewiseAverageCurve"
function build_pwl_average_fuel_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_pwl_incremental_fuel(node)
    oc = get_operation_cost(test_gen)
    vc = get_variable(oc)
    set_variable!(oc, FuelCurve(AverageRateCurve(get_value_curve(vc)), get_fuel_cost(vc)))
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

function build_non_convex_io_pwl_cost_test(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gen = thermal_generator_pwl_io_cost_nonconvex(node)
    PSY.add_component!(base_sys, test_gen)
    return base_sys
end

### Systems with time series fuel cost

function build_linear_fuel_test_sys_ts(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    thermal_generator_linear_fuel_ts(base_sys, node)
    return base_sys
end

function build_quadratic_fuel_test_sys_ts(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    thermal_generator_quad_fuel_ts(base_sys, node)
    return base_sys
end

function build_pwl_io_fuel_test_sys_ts(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    thermal_generator_pwl_io_fuel_ts(base_sys, node)
    return base_sys
end

function build_pwl_incremental_fuel_test_sys_ts(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    thermal_generator_pwl_incremental_fuel_ts(base_sys, node)
    return base_sys
end

### Systems with fixed market bid cost

function build_fixed_market_bid_cost_test_sys(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    test_gens = thermal_generators_market_bid(node)
    PSY.add_component!(base_sys, test_gens[1])
    PSY.add_component!(base_sys, test_gens[2])
    return base_sys
end

function build_pwl_marketbid_sys_ts(; kwargs...)
    base_sys = _build_cost_base_test_sys(; kwargs...)
    node = PSY.get_component(ACBus, base_sys, "nodeA")
    thermal_generators_market_bid_ts(base_sys, node)
    return base_sys
end
