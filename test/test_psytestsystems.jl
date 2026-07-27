@testset "Test IS.DataFormatError throw path" begin
    @test_throws IS.DataFormatError PSB.build_tamu_ACTIVSg2000_sys(;
        raw_data = mktempdir(),
    )
end

@testset "Test Serialization/De-Serialization PSY Tests" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    for (name, descriptor) in system_catalog.data[PSYTestSystems]
        # build a new system from scratch
        supported_args_permutations = PSB.get_supported_args_permutations(descriptor)
        if isempty(supported_args_permutations)
            sys = build_system(
                PSYTestSystems,
                name;
                force_build = true,
            )
            @test isa(sys, System)

            # build a new system from json
            @test PSB.is_serialized(name)
            sys2 = build_system(
                PSYTestSystems,
                name,
            )
            @test isa(sys2, System)

            PSB.clear_serialized_system(name)
            @test !PSB.is_serialized(name)
        end
        for supported_args in supported_args_permutations
            sys = build_system(
                PSYTestSystems,
                name;
                force_build = true,
                supported_args...,
            )
            @test isa(sys, System)

            # build a new system from json
            @test PSB.is_serialized(name, supported_args)
            sys2 = build_system(
                PSYTestSystems,
                name;
                supported_args...,
            )
            @test isa(sys2, System)

            PSB.clear_serialized_system(name, supported_args)
            @test !PSB.is_serialized(name, supported_args)
        end
    end
end
