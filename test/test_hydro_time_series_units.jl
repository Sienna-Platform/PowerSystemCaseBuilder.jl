labels(ts) = (
    IS.get_unit_system(ts),
    IS.get_units(ts),
    IS.get_quantity_kind(ts),
    IS.get_per_unit_of(ts),
)
_build(name; kwargs...) = build_system(
    PSITestSystems, name; force_build = true, skip_serialization = true, kwargs...)

@testset "Hydro test system data is stored in natural units" begin
    # An ENERGY reservoir: flows are the profile times the 100 MVA system base, levels the
    # profile times the reservoir's maximum. Both the single series and forecast branches.
    for single in (true, false)
        sys = _build("c_sys5_hy_turbine_energy";
            add_single_time_series = single, add_forecasts = !single)
        res = only(get_components(HydroReservoir, sys))
        max_level = get_storage_level_limits(res).max
        for (name, raw_single, raw_windows, scale, expected) in (
            ("inflow", PSB.hydro_single_timeseries_DA, PSB.hydro_timeseries_DA, 100.0,
                (IS.NU, "MW", "active_power", nothing)),
            ("storage_target", PSB.storage_target_single_ts_DA, PSB.storage_target_DA,
                max_level, (IS.NU, "MW*hr", "energy", nothing)),
        )
            if single
                ts = get_time_series(SingleTimeSeries, res, name)
                @test get_time_series_values(SingleTimeSeries, res, name) ≈
                      values(raw_single) .* scale
            else
                ts = get_time_series(Deterministic, res, name)
                window = raw_windows[1][1]
                @test get_time_series_values(Deterministic, res, name;
                    start_time = timestamp(window)[1]) ≈ values(window) .* scale
            end
            @test labels(ts) == expected
        end
    end

    # A water reservoir's flows are already m³/s, so they are kept as they are.
    sys = _build("c_sys5_hy_turbine_head"; add_single_time_series = true)
    res = only(get_components(HydroReservoir, sys))
    @test get_time_series_values(SingleTimeSeries, res, "inflow") ≈
          values(PSB.inflow_single_ts_DA_water)
    @test labels(get_time_series(SingleTimeSeries, res, "inflow")) ==
          (IS.NU, "m^3/s", "volume_flow_rate", nothing)

    # A battery's level stays CU of its capacity, values unchanged.
    sys = _build("c_sys5_bat_ems"; add_forecasts = true)
    battery = first(get_components(EnergyReservoirStorage, sys))
    ts = get_time_series(SingleTimeSeries, battery, "storage_target")
    @test labels(ts) == (IS.CU, nothing, "energy", "storage_capacity")
    @test get_time_series_values(SingleTimeSeries, battery, "storage_target") ≈
          values(PSB.storage_target_single_ts_DA)
end
