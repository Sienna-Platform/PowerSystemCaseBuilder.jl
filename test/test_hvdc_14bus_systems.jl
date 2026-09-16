@testset "Test HVDC 14-bus systems" begin
    @testset "c_sys14_hvdc_vsc" begin
        sys = build_system(
            PSITestSystems,
            "c_sys14_hvdc_vsc";
            force_build = true,
            add_forecasts = false,
        )
        @test isa(sys, System)
        @test length(collect(PSY.get_components(PSY.TwoTerminalVSCLine, sys))) == 1
    end

    @testset "c_sys14_hvdc_lcc" begin
        sys = build_system(
            PSITestSystems,
            "c_sys14_hvdc_lcc";
            force_build = true,
            add_forecasts = false,
        )
        @test isa(sys, System)
        @test length(collect(PSY.get_components(PSY.TwoTerminalLCCLine, sys))) == 1
    end

    @testset "pti_vsc_hvdc_test_sys rated AC voltage import" begin
        # vsc-hvdc_test.raw: bus 1001 base kV 230.0, bus 1002 base kV 87.0. The VSC
        # record carries no rated AC voltage; make_vscline must fall back to the
        # terminal buses' base voltages.
        sys = build_system(
            PSSEParsingTestSystems,
            "pti_vsc_hvdc_test_sys";
            force_build = true,
        )
        vsc_lines = collect(PSY.get_components(PSY.TwoTerminalVSCLine, sys))
        @test length(vsc_lines) == 1
        vsc = only(vsc_lines)
        arc = PSY.get_arc(vsc)
        @test PSY.get_rated_ac_voltage_from(vsc) ==
              PSY.get_base_voltage(PSY.get_from(arc))
        @test PSY.get_rated_ac_voltage_to(vsc) == PSY.get_base_voltage(PSY.get_to(arc))
        @test PSY.get_rated_ac_voltage_from(vsc) == 230.0
        @test PSY.get_rated_ac_voltage_to(vsc) == 87.0
    end
end
