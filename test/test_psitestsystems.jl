@testset "Test Serialization/De-Serialization PSI Cases" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    for (name, descriptor) in system_catalog.data[PSITestSystems]
        @testset "Test Serialization/De-Serialization for $name" begin
            # build a new system from scratch
            supported_args_permutations = PSB.get_supported_args_permutations(descriptor)
            if isempty(supported_args_permutations)
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
    @testset "Five-bus load profiles" begin
        catalog = SystemCatalog(SYSTEM_CATALOG)
        for name in ("c_sys5", "c_sys5_ml"), single in (false, true)
            descriptor = PSB.get_system_descriptor(PSITestSystems, catalog, name)
            case_args = PSB.filter_descriptor_kwargs(
                descriptor;
                add_single_time_series = single,
            )
            if single
                expected_by_name = Dict(
                    load_name => PSB.load_single_timeseries_DA[ix] for
                    (ix, load_name) in enumerate(("Bus2", "Bus3", "Bus4"))
                )
                series_type = PSY.SingleTimeSeries
            else
                expected_by_name = Dict(
                    load_name => [PSB.load_timeseries_DA[day][ix] for day in 1:2] for
                    (ix, load_name) in enumerate(("Bus2", "Bus3", "Bus4"))
                )
                series_type = PSY.Deterministic
            end

            try
                sys = build_system(PSITestSystems, name; force_build = true, case_args...)
                check_load_profiles(sys, expected_by_name, series_type)
                @test PSB.is_serialized(name, case_args)
                restored = build_system(PSITestSystems, name; case_args...)
                check_load_profiles(restored, expected_by_name, series_type)
            finally
                PSB.clear_serialized_system(name, case_args)
            end
        end

        hybrid = build_system(
            PSITestSystems,
            "c_sys5_hybrid";
            force_build = true,
            skip_serialization = true,
        )
        @test Set(
            PSY.get_name(PSY.get_electric_load(device)) for
            device in PSY.get_components(PSY.HybridSystem, hybrid) if
            !isnothing(PSY.get_electric_load(device))
        ) == Set(("Bus3", "Bus4"))
        for device in PSY.get_components(PSY.HybridSystem, hybrid)
            load = PSY.get_electric_load(device)
            if !isnothing(load)
                ix = findfirst(==(PSY.get_name(load)), ("Bus2", "Bus3", "Bus4"))
                actual = PSY.get_time_series_array(
                    PSY.Deterministic,
                    load,
                    "max_active_power";
                    ignore_scaling_factors = true,
                )
                @test TimeSeries.values(actual) ==
                      TimeSeries.values(PSB.load_timeseries_DA[1][ix])
                actual_single = PSY.get_time_series_array(
                    PSY.SingleTimeSeries,
                    load,
                    "max_active_power";
                    ignore_scaling_factors = true,
                )
                @test TimeSeries.values(actual_single) ==
                      TimeSeries.values(PSB.load_single_timeseries_DA[ix])
            end
        end
    end

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
