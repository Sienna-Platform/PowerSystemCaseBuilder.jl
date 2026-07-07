@testset "Test Serialization/De-Serialization Parsing System Tests" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    for case_type in [PSSEParsingTestSystems, MatpowerTestSystems]
        for (name, descriptor) in system_catalog.data[case_type]
            # isolated_bus_test.raw deliberately contains a topologically isolated
            # bus mistyped as PV (bus 16); the parser logs an error-level event and
            # demotes it to isolated. Assert the event fires and capture it so the
            # zero-error-event assertion in runtests.jl only counts unexpected errors.
            build = if name == "isolated_bus_test_system"
                () -> @test_logs (:error, r"topologically isolated bus") match_mode = :any build_system(
                    case_type,
                    name;
                    force_build = true,
                )
            else
                () -> build_system(case_type, name; force_build = true)
            end
            # build a new system from scratch
            sys = build()

            @test isa(sys, System)
            # build a new system from json
            @test PSB.is_serialized(name)
            sys2 = build()
            @test isa(sys2, System)

            PSB.clear_serialized_system(name)
            @test !PSB.is_serialized(name)
        end
    end
end
