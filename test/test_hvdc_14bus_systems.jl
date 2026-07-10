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
end
