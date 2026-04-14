@testset "build_system returns SYSTEM_BASE" begin
    # Matpower systems were previously built in DEVICE_BASE
    sys = build_system(MatpowerTestSystems, "matpower_case5_sys"; force_build = true)
    @test PSY.get_units_base(sys) == "SYSTEM_BASE"

    # Also test the deserialization path
    sys2 = build_system(MatpowerTestSystems, "matpower_case5_sys"; force_build = false)
    @test PSY.get_units_base(sys2) == "SYSTEM_BASE"
end
