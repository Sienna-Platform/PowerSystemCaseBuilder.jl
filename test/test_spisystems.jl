@testset "Test Serialization/De-Serialization SPI Tests" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    for (name, descriptor) in system_catalog.data[SPISystems]
        # build a new system from scratch
        supported_args_permutations = PSB.get_supported_args_permutations(descriptor)
        if isempty(supported_args_permutations)
            sys = build_system(
                SPISystems,
                name;
                force_build = true,
            )
            @test isa(sys, System)
            @test !iszero(
                get_supplemental_attributes(GeometricDistributionForcedOutage, sys).length,
            )
            if (occursin("TimeSeries", name))
                @test all(
                    has_time_series.(
                        first.(
                            get_supplemental_attributes.(
                                GeometricDistributionForcedOutage,
                                get_available_components(
                                    x -> get_max_active_power(x, Float64) > 0.0,
                                    ThermalGen,
                                    sys,
                                ),
                            )
                        )
                    ),
                )
            end

            # build a new system from json
            @test PSB.is_serialized(name)
            sys2 = build_system(
                SPISystems,
                name,
            )
            @test isa(sys2, System)
            @test !iszero(
                get_supplemental_attributes(GeometricDistributionForcedOutage, sys2).length,
            )
            if (occursin("TimeSeries", name))
                @test all(
                    has_time_series.(
                        first.(
                            get_supplemental_attributes.(
                                GeometricDistributionForcedOutage,
                                get_available_components(
                                    x -> get_max_active_power(x, Float64) > 0.0,
                                    ThermalGen,
                                    sys2,
                                ),
                            )
                        )
                    ),
                )
            end

            PSB.clear_serialized_system(name)
            @test !PSB.is_serialized(name)
        end
    end
end
