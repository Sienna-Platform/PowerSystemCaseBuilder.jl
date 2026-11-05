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

@testset "Two area system net interchange schedules and off-area load" begin
    sys = build_system(PSISystems, "two_area_pjm_DA"; force_build = true)
    for name in ("Area1", "Area2")
        area = PSY.get_component(PSY.Area, sys, name)
        @test isnothing(PSY.get_scheduled_net_interchange(area, u"SU"))
        @test isempty(PSY.get_out_of_area_loads(area))
    end

    sys = build_system(PSISystems, "two_area_pjm_DA_off_area_load"; force_build = true)
    area1 = PSY.get_component(PSY.Area, sys, "Area1")
    area2 = PSY.get_component(PSY.Area, sys, "Area2")
    @test iszero(PSY.get_scheduled_net_interchange(area1, u"SU"))
    @test iszero(PSY.get_scheduled_net_interchange(area2, u"SU"))
    @test isempty(PSY.get_out_of_area_loads(area2))
    loads = PSY.get_out_of_area_loads(area1)
    @test length(loads) == 1
    load = only(loads)
    @test PSY.get_name(load) == "OffAreaLoad"
    @test PSY.get_name(PSY.get_area(PSY.get_bus(load))) == "Area2"
    @test PSY.get_constant_active_power(load, u"SU") ≈ 0.2
    @test PSY.get_current_active_power(load, u"SU") ≈ 0.1
    @test PSY.get_impedance_active_power(load, u"SU") ≈ 0.08

    sys2 = build_system(PSISystems, "two_area_pjm_DA_off_area_load")
    area1 = PSY.get_component(PSY.Area, sys2, "Area1")
    @test PSY.get_name(only(PSY.get_out_of_area_loads(area1))) == "OffAreaLoad"
    PSB.clear_serialized_system("two_area_pjm_DA_off_area_load")
end
