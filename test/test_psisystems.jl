@testset "Test Serialization/De-Serialization PSI Tests" begin
    system_catalog = SystemCatalog(SYSTEM_CATALOG)
    for (name, descriptor) in system_catalog.data[PSISystems]
        supported_args_permutations = PSB.get_supported_args_permutations(descriptor)
        if isempty(supported_args_permutations)
            sys = build_system(
                PSISystems,
                name;
                force_build = true,
            )
            @test isa(sys, System)

            # build a new system from json
            @test PSB.is_serialized(name)
            sys2 = build_system(
                PSISystems,
                name,
            )
            @test isa(sys2, System)

            PSB.clear_serialized_system(name)
            @test !PSB.is_serialized(name)
        end
        for supported_args in supported_args_permutations
            sys = build_system(
                PSISystems,
                name;
                force_build = true,
                supported_args...,
            )
            @test isa(sys, System)

            # build a new system from json
            @test PSB.is_serialized(name, supported_args)
            sys2 = build_system(
                PSISystems,
                name;
                supported_args...,
            )
            @test isa(sys2, System)

            PSB.clear_serialized_system(name, supported_args)
            @test !PSB.is_serialized(name, supported_args)
        end
    end
end

@testset "Test PWL functions match in 2-RTO systems" begin
    sys_twin_rts_DA = build_system(PSISystems, "AC_TWO_RTO_RTS_1Hr_sys")
    sys_twin_rts_HA = build_system(PSISystems, "AC_TWO_RTO_RTS_5min_sys")
    for g in get_components(ThermalStandard, sys_twin_rts_DA)
        component_RT = get_component(ThermalStandard, sys_twin_rts_HA, get_name(g))
        @test get_variable_operation_cost(get_operation_cost(g)) ==
              get_variable_operation_cost(get_operation_cost(component_RT))
    end
end
