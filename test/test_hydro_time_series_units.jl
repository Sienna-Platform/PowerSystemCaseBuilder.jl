labels(ts) = (
    IS.get_unit_system(ts),
    IS.get_units(ts),
    IS.get_quantity_kind(ts),
    IS.get_per_unit_of(ts),
)
_build(name; kwargs...) = build_system(
    PSITestSystems, name; force_build = true, skip_serialization = true, kwargs...)

@testset "Hydro test system data is stored in natural units" begin
    # An ENERGY reservoir: inflow (MW) and budget (MWh per step) are stored as the data
    # gives them, levels as the profile times the reservoir's maximum. Both the single
    # series and forecast branches.
    for single in (true, false)
        sys = _build("c_sys5_hy_turbine_energy";
            add_single_time_series = single, add_forecasts = !single)
        res = only(get_components(HydroReservoir, sys))
        max_level = get_storage_level_limits(res).max
        @test get_inflow(res) == PSB.reservoir_inflow_mw == 400.0
        for (name, raw_single, raw_windows, scale, expected) in (
            ("inflow", PSB.reservoir_inflow_single_ts_DA, PSB.reservoir_inflow_DA, 1.0,
                (IS.NU, "MW", "active_power", nothing)),
            ("hydro_budget", PSB.hydro_budget_single_ts_DA, PSB.hydro_budget_DA, 1.0,
                (IS.NU, "MW*hr", "energy", nothing)),
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

@testset "Hydro pump test systems keep every reservoir an ENERGY reservoir" begin
    for (name, turbines) in
        (("c_sys5_hy_pump_turbine_energy", 1), ("c_sys5_hy_pump_only_energy", 0))
        sys = _build(name)
        @test length(get_components(HydroTurbine, sys)) == turbines
        @test length(get_components(HydroPumpTurbine, sys)) == 1
        for res in get_components(HydroReservoir, sys)
            @test get_level_data_type(res) == ReservoirDataType.ENERGY
            @test labels(get_time_series(Deterministic, res, "hydro_budget")) ==
                  (IS.NU, "MW*hr", "energy", nothing)
            @test labels(get_time_series(Deterministic, res, "inflow")) ==
                  (IS.NU, "MW", "active_power", nothing)
        end
    end
end

@testset "Hydro pump test systems keep a contributor for every reserve" begin
    for name in ("c_sys5_hy_pump_turbine_energy", "c_sys5_hy_pump_only_energy")
        sys = _build(name; add_reserves = true)
        services = collect(get_components(OnlineReserve, sys))
        @test !isempty(services)
        for serv in services
            @test !isempty(get_contributing_devices(sys, serv))
        end
    end
end

@testset "c_sys5_hy_small_reserves states every requirement as 1 MW" begin
    sys = _build(
        "c_sys5_hy_small_reserves";
        add_single_time_series = true,
        add_reserves = true,
    )
    for serv in get_components(OnlineReserve, sys)
        @test get_requirement(serv, u"MW") ≈ 1.0
        @test maximum(get_time_series_values(SingleTimeSeries, serv, "requirement")) <= 1.0
    end
end
