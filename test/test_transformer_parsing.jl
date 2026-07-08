# Field-level assertions for transformer parsing (TwoWindingTransformer /
# ThreeWindingTransformer with per-winding TransformerWinding + TransformerControl).
#
# All literal expectations below are derived directly from the raw PSS/E fixture
# text (see the inline "raw:" citations), never from the parser output.

@testset "PSSE 2W/3W transformer parsing (case14_with_pst3w)" begin
    sys = build_system(
        PSSEParsingTestSystems,
        "pti_case14_with_pst3w_sys";
        force_build = true,
    )

    # raw case14_with_pst3w.raw TRANSFORMER section: two 3W records
    # (109-104-107 "TRAFO 3W 2", 113-110-114 "TRAFO 3W 1") and three 2W records
    # (109-104 "TRAFO 2W 3", 106-105 "TRAFO 2W 1", 110-109 "TRAFO 2W 2").
    t3ws = collect(get_components(ThreeWindingTransformer, sys))
    @test length(t3ws) == 2
    t2ws = collect(get_components(TwoWindingTransformer, sys))
    @test length(t2ws) == 3

    # Phase shifting is winding data (raw ANG1); shifters are found by angle. Two
    # of the three 2W records carry a nonzero winding angle: "TRAFO 2W 3" = 50.0 deg and
    # "TRAFO 2W 2" = -60.0 deg; "TRAFO 2W 1" = 0.0 deg is not phase shifting.
    phase_shifting_2w = filter(t -> PSY.is_phase_shifting(PSY.get_winding(t)), t2ws)
    @test length(phase_shifting_2w) == 2

    # Select the 50 deg shifter by its angle (raw ANG1 = 50.0 deg).
    pst = only(
        t for
        t in t2ws if isapprox(PSY.get_α(PSY.get_winding(t)), deg2rad(50.0); atol = 1e-9)
    )
    @test PSY.get_α(PSY.get_winding(pst)) ≈ deg2rad(50.0) atol = 1e-9

    # COD spot-check for the 50 deg 2W winding. raw winding-1 line:
    # WINDV1=0.95 ANG1=50 ... COD1=0 CONT1=0 RMA1=1.10 RMI1=0.90 VMA1=1.10 VMI1=0.90 NTP1=33
    pst_control = PSY.get_control(PSY.get_winding(pst))
    @test !isnothing(pst_control)
    @test get_objective(pst_control) == TransformerControlObjective.FIXED   # COD1 = 0
    @test PSY.get_regulated_bus_number(pst_control) == 0                     # CONT1 = 0
    @test get_number_of_tap_positions(pst_control) == 33                     # NTP1 = 33
    @test PSY.get_limits(pst_control) == (min = 0.9, max = 1.1)              # RMI1 / RMA1

    for t in t3ws
        for w in get_windings(t)
            c = get_control(w)
            if !isnothing(c)
                # Every 3W winding in this fixture carries COD = 0 (FIXED); raw
                # winding lines all show a "0" COD field.
                @test get_objective(c) == TransformerControlObjective.FIXED
                @test get_objective(c) != TransformerControlObjective.UNDEFINED
                @test get_number_of_tap_positions(c) >= 0
            end
        end
        @test PSY.get_x_12(t, DU) != 0.0
        @test PSY.get_star_bus(t) in get_components(ACBus, sys)
        @test all(w -> PSY.get_arc(w) in get_components(Arc, sys), get_windings(t))
    end

    # Winding base follows the parse convention: the primary winding's base_power
    # equals the primary-secondary pairwise base (base_power_12).
    t3w = first(t3ws)
    @test PSY.get_base_power(PSY.get_primary_winding(t3w)) ==
          PowerSystems.get_base_power_12(t3w)
end

@testset "transformer base convention (hand-computed)" begin
    # --- 2W passthrough (case14_with_pst3w) ---
    # Every 2W record in the corpus has SBASE1-2 == system base (100), so device
    # base == system base for 2W and DU == SU. "TRAFO 2W 1" (106-105) has
    # raw X1-2 = 1.0e-4, CZ=1, CW=1, NOMV1=0, WINDV1=0.85, WINDV2=1.0, so the
    # device-base reactance is X1-2 * (base_power/system_base) * WINDV2^2 = 1.0e-4
    # and its tap is WINDV1/WINDV2 = 0.85. This proves the maker passes br_r/br_x
    # through unchanged (no rebase).
    sys = build_system(
        PSSEParsingTestSystems,
        "pti_case14_with_pst3w_sys";
        force_build = true,
    )
    t2ws = collect(get_components(TwoWindingTransformer, sys))
    t_2w1 = only(
        t for t in t2ws if isapprox(PSY.get_tap(PSY.get_winding(t)), 0.85; atol = 1e-9)
    )
    @test PSY.get_x(t_2w1, DU) ≈ 1.0e-4 atol = 1e-12
    @test PSY.get_r(t_2w1, DU) ≈ 0.0 atol = 1e-12

    # --- 3W discriminating proof (case4_zero_impedance_3wt) ---
    # raw 3W record 102-103-104: CZ=2 (per-pair-base pu, passthrough) with
    # SBASE1-2 = 15.00, R1-2 = 5.0e-3, X1-2 = 5.0e-2. Device (pair) base = 15,
    # system base = 100. PSY.get_x_12(DU) must equal the raw device-base value 5.0e-2
    # (i.e. NOT rebased to system base, which would give 5.0e-2 * 15/100), and the
    # SU value is that device value converted with the 15-MVA base.
    sys4 =
        build_system(
            PSSEParsingTestSystems,
            "psse_4_zero_impedance_3wt_test_system";
            force_build = true,
        )
    t = first(get_components(ThreeWindingTransformer, sys4))
    @test PowerSystems.get_base_power_12(t) == 15.0
    @test PSY.get_base_power(PSY.get_primary_winding(t)) == 15.0
    @test PSY.get_x_12(t, DU) ≈ 5.0e-2 atol = 1e-9
    @test PSY.get_r_12(t, DU) ≈ 5.0e-3 atol = 1e-9
    @test PSY.get_x_12(t, SU) ≈ 5.0e-2 * (100.0 / 15.0) atol = 1e-9
end

@testset "inverted control band warns and normalizes" begin
    # Mirrors frankenstein_70.raw, where VMA1 = 0.984 < VMI1 = 0.985 (a benign
    # rounding artifact). The maker must warn (naming the record) and normalize
    # the band rather than silently swallowing potentially corrupt data.
    d = Dict{String, Any}(
        "name" => "synthetic-record",
        "COD1" => 0,
        "CONT1" => 0,
        "RMA1" => 1.5,
        "RMI1" => 0.5,
        "VMA1" => 0.984,
        "VMI1" => 0.985,
        "NTP1" => 33,
    )
    ctrl =
        @test_logs (:warn, r"synthetic-record.*inverted controlled-quantity limits") match_mode =
            :any PSB._make_transformer_control(
            d,
            1,
        )
    @test PSY.get_controlled_quantity_limits(ctrl) == (min = 0.984, max = 0.985)
    @test PSY.get_limits(ctrl) == (min = 0.5, max = 1.5)

    # Inverted RMI/RMA warns too.
    d["RMI1"], d["RMA1"] = 1.5, 0.5
    d["VMI1"], d["VMA1"] = 0.9, 1.1
    ctrl2 =
        @test_logs (:warn, r"synthetic-record.*inverted control limits") match_mode = :any PSB._make_transformer_control(
            d,
            1,
        )
    @test PSY.get_limits(ctrl2) == (min = 0.5, max = 1.5)
end

@testset "3W zero-impedance and mag fixtures build" begin
    for name in ("psse_4_zero_impedance_3wt_test_system", "pti_three_winding_mag_test_sys",
        "pti_three_winding_test_sys", "pti_three_winding_test_2_sys")
        sys = build_system(PSSEParsingTestSystems, name; force_build = true)
        @test !isempty(get_components(ThreeWindingTransformer, sys))
    end
end

@testset "tabular parser (RTS-GMLC) 2W transformer construction" begin
    # `test_RTS_GMLC_sys` is built via `power_system_table_data.jl`'s
    # `branch_csv_parser!` (PowerTableDataParser.PowerSystemTableData), the only
    # tabular-parser test system in the descriptor list that contains
    # transformers. Skip forecast construction (irrelevant here, and slow).
    sys = build_system(
        PSITestSystems,
        "test_RTS_GMLC_sys";
        add_forecasts = false,
        force_build = true,
    )

    # raw RTS-GMLC branch.csv: exactly 15 rows have `Tr Ratio` (tap) neither 0
    # nor 1 (A7, A14-A17, B7, B14-B17, C7, C14-C17) -- these are the only rows
    # `get_branch_type` classifies as transformers under automatic inference;
    # all others are `Line`s.
    t2ws = collect(get_components(TwoWindingTransformer, sys))
    @test length(t2ws) == 15

    # A7: From Bus 103 ("Adler", 138 kV) -> To Bus 124 ("Avery", 230 kV),
    # Tr Ratio = 1.015, B = 0. `name` is mapped directly from the branch UID.
    t_a7 = get_component(TwoWindingTransformer, sys, "A7")
    @test !isnothing(t_a7)
    w_a7 = get_winding(t_a7)
    @test PSY.get_tap(w_a7) ≈ 1.015 atol = 1e-9
    @test PSY.get_winding_group_number(w_a7) == WindingGroupNumber.UNDEFINED
    @test isnothing(PSY.get_control(w_a7))
    @test PSY.get_available(w_a7)
    # parent/winding base_power invariant (both set from the table's system base)
    @test PSY._get_base_power(t_a7) == PSY.get_base_power(w_a7)
    # base_voltage defaults from the from-bus (103 "Adler" = 138 kV).
    @test PSY.get_base_voltage(w_a7) == 138.0
    # B = 0 for every transformer row in this fixture, so magnetizing_shunt
    # (mapped straight from `primary_shunt`) is a pure-real zero.
    @test PSY.get_magnetizing_shunt(t_a7, DU) == 0.0

    # A14: From Bus 109 ("Ali", 138 kV) -> To Bus 111, Tr Ratio = 1.03.
    t_a14 = get_component(TwoWindingTransformer, sys, "A14")
    @test !isnothing(t_a14)
    @test PSY.get_tap(get_winding(t_a14)) ≈ 1.03 atol = 1e-9
    @test PSY.get_base_voltage(get_winding(t_a14)) == 138.0
end
