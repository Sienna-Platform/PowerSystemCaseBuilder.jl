# Every system that carries dynamic injectors (hand-built and .dyr) must survive a PSY
# document write and read with every field of every component unchanged.
@testset "Dynamics document round trip" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    n_dynamic = 0
    for case_type in
        [PSIDTestSystems, PSIDSystems, PSYTestSystems, PSSEParsingTestSystems]
        for (name, descriptor) in system_catalog.data[case_type]
            if haskey(EXPECTED_BUILD_LOG_ERRORS, name)
                continue # corrupt-data fixture without dynamics; built in test_parsingtestsystems
            end
            permutations = PSB.get_supported_args_permutations(descriptor)
            if isempty(permutations)
                permutations = [Dict{Symbol, Any}()]
            end
            for supported_args in permutations
                sys = build_system(
                    case_type,
                    name;
                    force_build = true,
                    skip_serialization = true,
                    supported_args...,
                )
                if iszero(count_dynamic_injectors(sys))
                    continue
                end
                n_dynamic += 1
                differences = compare_systems(sys, roundtrip_system(sys))
                @test isempty(differences)
                if !isempty(differences)
                    @error "round trip differences" name supported_args differences = first(
                        differences,
                        20,
                    )
                end
            end
        end
    end
    @test n_dynamic > 40
end
