const PSID_BUILD_TESTS =
    ["psid_psse_test_avr", "psid_psse_test_tg", "psid_psse_test_gen", "psid_psse_test_pss"]

@testset "Test Serialization/De-Serialization PSID Tests" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    for case_type in [PSIDTestSystems, PSIDSystems]
        for (name, descriptor) in system_catalog.data[case_type]
            if name in PSID_BUILD_TESTS
                supported_args_permutations =
                    PSB.get_supported_args_permutations(descriptor)
                @test !isempty(supported_args_permutations)
            else
                supported_args_permutations = [Dict{Symbol, Any}()]
            end
            for supported_arg in supported_args_permutations
                sys = build_system(
                    case_type,
                    name;
                    force_build = true,
                    supported_arg...,
                )
                @test isa(sys, System)
                @test PSB.is_serialized(name, supported_arg)
                sys2 = build_system(case_type, name; supported_arg...)
                @test isa(sys2, System)
                PSB.clear_serialized_system(name, supported_arg)
                @test !PSB.is_serialized(name, supported_arg)
            end
        end
    end
end
