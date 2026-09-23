# Branch/transformer component naming from PSS(R)E source ids.
#
# A PSS(R)E circuit id occupies a two-character field, so " 1" and "1 " identify different
# circuits on the same bus pair. Component names strip the id, which is what nearly every
# record wants -- padding is almost always on the right -- but two parallel circuits padded
# on opposite sides then collide on one name.

function _naming_test_bus(number, name)
    return ACBus(;
        number = number,
        name = name,
        available = true,
        bustype = ACBusTypes.PQ,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.9, max = 1.1),
        base_voltage = 138.0,
    )
end

@testset "PSS(R)E branch naming from circuit ids" begin
    bus_f = _naming_test_bus(1, "BUS_F")
    bus_t = _naming_test_bus(2, "BUS_T")

    # source_id layouts the PSS(R)E parser emits:
    #   branch:      ["branch", I, J, CKT]
    #   transformer: ["transformer", I, J, K, CKT, 0]
    branch(ckt) = Dict{String, Any}("source_id" => ["branch", 1, 2, ckt], "index" => 7)
    xfmr(ckt) = Dict{String, Any}("source_id" => ["transformer", 1, 2, 0, ckt, 0])

    # Shorthands: the default (stripped) name and the verbatim one.
    nm(d) = PSB._get_pm_branch_name(d, bus_f, bus_t)
    raw_nm(d) = PSB._get_pm_branch_name(d, bus_f, bus_t; strip_circuit_id = false)

    @testset "padding is stripped by default" begin
        for d in (branch("1 "), branch(" 1"), branch("1"))
            @test nm(d) == "BUS_F-BUS_T-i_1"
        end
        for d in (xfmr("1 "), xfmr(" 1"), xfmr("1"))
            @test nm(d) == "BUS_F-BUS_T-i_1"
        end
    end

    @testset "strip_circuit_id = false keeps the id verbatim" begin
        @test raw_nm(branch("1 ")) == "BUS_F-BUS_T-i_1 "
        @test raw_nm(branch(" 1")) == "BUS_F-BUS_T-i_ 1"
        @test raw_nm(xfmr("1 ")) == "BUS_F-BUS_T-i_1 "
        @test raw_nm(xfmr(" 1")) == "BUS_F-BUS_T-i_ 1"
    end

    @testset "opposite padding collides when stripped, separates when not" begin
        # The real-data case: two parallel transformers, ids " 1" and "1 ".
        a, b = xfmr(" 1"), xfmr("1 ")
        @test nm(a) == nm(b)
        @test raw_nm(a) != raw_nm(b)
    end

    @testset "an explicit name wins over the circuit id" begin
        d = Dict{String, Any}("name" => "EXPLICIT", "source_id" => ["branch", 1, 2, "1 "])
        @test nm(d) == "BUS_F-BUS_T-i_EXPLICIT"
        @test raw_nm(d) == "BUS_F-BUS_T-i_EXPLICIT"
    end

    @testset "marker-prefixed switch ids keep their existing handling" begin
        # Legacy switches/breakers modeled as branches carry an '@'/'*' marker.
        d = Dict{String, Any}("source_id" => ["switch", 1, 2, "@1 "])
        @test nm(d) == "BUS_F-BUS_T-i_1"
        @test raw_nm(d) == "BUS_F-BUS_T-i_1 "
    end
end
