"""
FuelCost (`FuelCurve`/`set_fuel_cost!` time-series-backed fuel cost curves) has no OpenAPI
document converter yet — `_fuel_cost_to_openapi(::ForecastKey)` is unimplemented in
PowerSystems. Out of scope for this pass: the build itself is still exercised (with
serialization skipped) and the cache round trip is skipped with a named, loud reason instead
of failing as ordinary drift.
"""
const FUEL_COST_PENDING = Set([
    "c_sys5_re_fuel_cost",
    "c_linear_fuel_test_ts",
    "c_pwl_io_fuel_test_ts",
    "c_quadratic_fuel_test_ts",
    "c_pwl_incremental_fuel_test_ts",
])

"""
MarketBidCost has no complete OpenAPI conversion coverage. `convert_cost_to_openapi` has no
case for `MarketBidTimeSeriesCost` — the export side, hit by `c_market_bid_cost`'s
time-series-backed offer curves. `convert_cost` has no case for the `MarketBidCost1` oneOf
variant — the import side, hit on cache read-back by every `HybridSystem`'s default
`MarketBidCost(nothing)` operation cost. Out of scope for this pass: the build itself is
still exercised (with serialization skipped) and the cache round trip is skipped with a
named, loud reason instead of failing as ordinary drift.
"""
const MARKET_BID_COST_PENDING = Set([
    "c_sys5_hybrid",
    "c_sys5_hybrid_ed",
    "c_sys5_hybrid_uc",
    "test_RTS_GMLC_sys_with_hybrid",
    "c_market_bid_cost",
])

@testset "Test Serialization/De-Serialization PSI Cases" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    for (name, descriptor) in system_catalog.data[PSITestSystems]
        @testset "Test Serialization/De-Serialization for $name" begin
            # build a new system from scratch
            supported_args_permutations = PSB.get_supported_args_permutations(descriptor)
            if name in FUEL_COST_PENDING
                sys = build_system(
                    PSITestSystems,
                    name;
                    force_build = true,
                    skip_serialization = true,
                )
                @test isa(sys, System)
                println(
                    "SKIP (FuelCost pending): $name — FuelCurve/set_fuel_cost! time " *
                    "series has no OpenAPI export coverage yet",
                )
                @test_skip PSB.is_serialized(name)
            elseif name in MARKET_BID_COST_PENDING
                sys = build_system(
                    PSITestSystems,
                    name;
                    force_build = true,
                    skip_serialization = true,
                )
                @test isa(sys, System)
                println(
                    "SKIP (MarketBidCost pending): $name — MarketBidCost has no " *
                    "complete OpenAPI export/import coverage yet",
                )
                @test_skip PSB.is_serialized(name)
            elseif isempty(supported_args_permutations)
                sys = build_system(
                    PSITestSystems,
                    name;
                    force_build = true,
                )
                @test isa(sys, System)

                # build a new system from json
                @test PSB.is_serialized(name)
                sys2 = build_system(
                    PSITestSystems,
                    name,
                )
                @test isa(sys2, System)

                PSB.clear_serialized_system(name)
                @test !PSB.is_serialized(name)
            end
            name in FUEL_COST_PENDING && continue
            name in MARKET_BID_COST_PENDING && continue
            for supported_args in supported_args_permutations
                sys = build_system(
                    PSITestSystems,
                    name;
                    force_build = true,
                    supported_args...,
                )
                @test isa(sys, System)

                # build a new system from json
                @test PSB.is_serialized(name, supported_args)
                sys2 = build_system(
                    PSITestSystems,
                    name;
                    supported_args...,
                )
                @test isa(sys2, System)

                PSB.clear_serialized_system(name, supported_args)
                @test !PSB.is_serialized(name, supported_args)
            end
        end
    end
end

@testset "Test PSI Cases' Specific Behaviors" begin
    """
    Make sure c_sys5_all_components has both a PowerLoad and a StandardLoad, as guaranteed
    """
    function test_c_sys5_all_components()
        sys = build_system(PSITestSystems, "c_sys5_all_components"; force_build = true)
        @test length(PSY.get_components(PSY.StaticLoad, sys)) >= 2
        @test length(PSY.get_components(PSY.PowerLoad, sys)) >= 1
        @test length(PSY.get_components(PSY.StandardLoad, sys)) >= 1
    end
    test_c_sys5_all_components()
end
