# Fixtures that carry corrupt data which the parser should report at error level.
const EXPECTED_BUILD_LOG_ERRORS = Dict(
    "isolated_bus_test_system" => r"topologically isolated bus",
)

function build_parsing_test_system(case_type, name)
    expected_error = get(EXPECTED_BUILD_LOG_ERRORS, name, nothing)
    if isnothing(expected_error)
        return build_system(case_type, name; force_build = true)
    end
    return @test_logs (:error, expected_error) match_mode = :any build_system(
        case_type,
        name;
        force_build = true,
    )
end

@testset "Test Serialization/De-Serialization Parsing System Tests" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    for case_type in [PSSEParsingTestSystems, MatpowerTestSystems]
        for (name, descriptor) in system_catalog.data[case_type]
            # build a new system from scratch
            sys = build_parsing_test_system(case_type, name)

            @test isa(sys, System)

            # Dynamic injectors have no OpenAPI document converter (PSY's
            # `is_document_exportable`), so build_system deliberately skips caching them.
            if PSB.is_serialized(name)
                sys2 = build_parsing_test_system(case_type, name)
                @test isa(sys2, System)

                PSB.clear_serialized_system(name)
                @test !PSB.is_serialized(name)
            else
                println(
                    "SKIP (Dynamics pending): $name is not cached — it carries dynamic " *
                    "injector components with no OpenAPI export coverage",
                )
                @test_skip PSB.is_serialized(name)
            end
        end
    end
end
