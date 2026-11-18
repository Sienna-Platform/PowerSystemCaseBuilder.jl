# HybridSystem is slated for deletion. PowerSystems copies its subcomponent time series again
# on a document import, so these systems do not survive the cache round trip.
const HYBRID_SYSTEMS = Set([
    "c_sys5_hybrid",
    "c_sys5_hybrid_ed",
    "c_sys5_hybrid_uc",
    "test_RTS_GMLC_sys_with_hybrid",
])

@testset "Test Serialization/De-Serialization PSI Cases" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    for (name, descriptor) in system_catalog.data[PSITestSystems]
        name in HYBRID_SYSTEMS && continue
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
