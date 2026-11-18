@testset "Market bid cost scenarios write their power series in MW" begin
    mw_values(c, name) =
        get_time_series_values(Deterministic, c, name, u"MW"; quantity = :ActivePower)

    sys = build_system(PSITestSystems, "c_sys5_pglib"; force_build = true)
    PSB.force_multistart_commitment!(sys, 2:3)
    load = get_component(PowerLoad, sys, PSB.MULTISTART_LOAD)
    values = mw_values(load, "max_active_power")
    @test values[2] ≈ PSB.MULTISTART_OFF_LOAD_MW
    @test values[1] ≈ PSB.MULTISTART_ON_LOAD_MW
    @test length(get_components(StaticInjection, sys)) == 3

    sys = build_system(PSITestSystems, "c_fixed_market_bid_cost"; force_build = true)
    load = first(get_components(PowerLoad, sys))
    before = mw_values(load, "max_active_power")
    PSB.scale_time_series!(sys, load, "max_active_power", 0.8)
    @test mw_values(load, "max_active_power") ≈ 0.8 .* before
    PSB.set_constant_max_active_power!(sys, load)
    @test all(≈(maximum(0.8 .* before)), mw_values(load, "max_active_power"))

    unit = get_component(ThermalStandard, sys, "Test Unit1")
    max_mw = get_active_power_limits(unit, u"MW").max
    renewable = PSB.replace_with_renewable!(sys, unit; use_thermal_max_power = true)
    @test isnothing(get_component(ThermalStandard, sys, "Test Unit1"))
    @test all(≈(max_mw), mw_values(renewable, "max_active_power"))
    cost = get_operation_cost(renewable)
    @test get_start_up(cost) == (hot = 0.0, warm = 0.0, cold = 0.0)
end
