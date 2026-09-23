# Literal expectations are read from case25_v35_savnwb.raw's SWITCHED SHUNT section.

@testset "PSSE v35 switched shunt solved_admittance and solved_case" begin
    raw = joinpath(PSB.DATA_DIR, "psse_raw", "case25_v35_savnwb.raw")
    # Names are `<bus>-<running index>`: 101 '1' is "101-1", 104 '1' is "104-5".
    shunt_at(sys, name) = get_component(SwitchedAdmittance, sys, name)

    # raw: 101 '1' MODSW=1, BINIT=-115.00 (discrete: BINIT is only a starting value);
    #      104 '1' MODSW=2, BINIT=245.63 (continuous: BINIT is always the admittance).
    sys = PSB.system_via_power_models(raw)
    @test isnothing(get_solved_admittance(shunt_at(sys, "101-1")))
    @test get_solved_admittance(shunt_at(sys, "104-5")) ≈ 2.4563

    solved = PSB.system_via_power_models(raw; solved_case = true)
    @test get_solved_admittance(shunt_at(solved, "101-1")) ≈ -1.15
    @test get_solved_admittance(shunt_at(solved, "104-5")) ≈ 2.4563
end
