# PSID cases creation
function build_psid_4bus_multigen(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    raw_file = joinpath(raw_data, "FourBusMulti.raw")
    dyr_file = joinpath(raw_data, "FourBus_multigen.dyr")

    sys = System(raw_file, dyr_file; sys_kwargs...)
    for l in get_components(PSY.StandardLoad, sys)
        transform_load_to_constant_impedance(l)
    end
    return sys
end

function build_psid_11bus_andes(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    raw_file = joinpath(raw_data, "11BUS_KUNDUR.raw")
    dyr_file = joinpath(raw_data, "11BUS_KUNDUR_TGOV.dyr")
    sys = System(raw_file, dyr_file; sys_kwargs...)
    for l in get_components(PSY.StandardLoad, sys)
        transform_load_to_constant_impedance(l)
    end
    return sys
end

function build_psid_omib(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys_file = joinpath(DATA_DIR, "psid_tests", "data_examples", "omib_sys.json")
    sys = System(sys_file; sys_kwargs...)
    return sys
end

function build_psid_3bus(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys_file = joinpath(DATA_DIR, "psid_tests", "data_examples", "threebus_sys.json")
    sys = System(sys_file; sys_kwargs...)
    return sys
end

function build_wecc_240_dynamic(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys_file = joinpath(DATA_DIR, "psid_tests", "data_tests", "WECC_240_dynamic.json")
    sys = System(sys_file; sys_kwargs...)
    return sys
end

function build_psid_14bus_multigen(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    raw_file = joinpath(raw_data, "14bus.raw")
    dyr_file = joinpath(raw_data, "dyn_data.dyr")

    sys = System(raw_file, dyr_file; sys_kwargs...)
    for l in get_components(PSY.StandardLoad, sys)
        transform_load_to_constant_impedance(l)
    end
    return sys
end

function build_3bus_inverter(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    raw_file = joinpath(raw_data, "ThreeBusInverter.raw")
    sys = System(raw_file; sys_kwargs...)
    return sys
end

function build_psid_wecc_9_dynamic(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = System(raw_data; runchecks = false, sys_kwargs...)

    # Manually change reactance of three branches to match Sauer & Pai (2007) Figure 7.4
    set_x!(get_component(Branch, sys, "Bus 5-Bus 4-i_1"), 0.085)
    set_x!(get_component(Branch, sys, "Bus 9-Bus 6-i_1"), 0.17)
    set_x!(get_component(Branch, sys, "Bus 7-Bus 8-i_1"), 0.072)

    # Loads from raw file are constant power, consistent with Sauer & Pai (p169)

    ############### Data Dynamic devices ########################

    # --- Machine models ---
    # All parameters are from Sauer & Pai (2007) Table 7.3 M/C columns 1,2,3
    function machine_sauerpai(i)
        R = [0.0, 0.0, 0.0] # <-- not specified in Table 7.3
        Xd = [0.146, 0.8958, 1.3125]
        Xq = [0.0969, 0.8645, 1.2578]
        Xd_p = [0.0608, 0.1198, 0.1813]
        Xq_p = [0.0969, 0.1969, 0.25]
        Td0_p = [8.96, 6.0, 5.89]
        Tq0_p = [0.31, 0.535, 0.6]
        return PSY.OneDOneQMachine(;
            R = R[i],
            Xd = Xd[i],
            Xq = Xq[i],
            Xd_p = Xd_p[i],
            Xq_p = Xq_p[i],
            Td0_p = Td0_p[i],
            Tq0_p = Tq0_p[i],
        )
    end

    # --- Shaft models ---
    # All parameters are from Sauer & Pai (2007)
    function shaft_sauerpai(i)
        D_M = [0.1, 0.2, 0.3] # D/M from bottom of p165
        H = [23.64, 6.4, 3.01] # H from Table 7.3
        D = (2 * D_M .* H) / get_frequency(sys)
        return PSY.SingleMass(;
            H = H[i],
            D = D[i],
        )
    end

    # --- AVR models ---
    # All parameters are from Sauer & Pai (2007) Table 7.3 exciter columns 1,2,3
    # All S&P exciters are IEEE-Type I (p165)
    # NOTE: In S&P, terminal voltage seen by AVR is same as the bus voltage.
    #  In AVRTypeI, it is a measurement if the bus voltage with a sampling rate. 
    #  Thus, Tr is set to be very small to account for this difference.
    avr_typei() = PSY.AVRTypeI(;
        Ka = 20,
        Ke = 1.0,
        Kf = 0.063,
        Ta = 0.2,
        Te = 0.314,
        Tf = 0.35,
        Tr = 0.0001, # <-- not specified in Table 7.3
        Va_lim = (-0.5, 0.5), # <-- not specified in Table 7.3 
        Ae = 0.0039,
        Be = 1.555,
    )

    function dyn_gen_sauerpai(generator)
        i = get_number(get_bus(generator))
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_sauerpai(i),
            shaft = shaft_sauerpai(i),
            avr = avr_typei(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    for g in get_components(Generator, sys)
        case_gen = dyn_gen_sauerpai(g)
        add_component!(sys, case_gen, g)
    end

    return sys
end

##################################
# Add Load tutorial systems here #
##################################

function build_psid_load_tutorial_omib(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = System(raw_data; runchecks = false, sys_kwargs...)
    l = first(get_components(StandardLoad, sys))
    exp_load = PSY.ExponentialLoad(;
        name = PSY.get_name(l),
        available = PSY.get_available(l),
        bus = PSY.get_bus(l),
        active_power = PSY.get_constant_active_power(l),
        reactive_power = PSY.get_constant_reactive_power(l),
        α = 0.0, # Constant Power
        β = 0.0, # Constant Power
        base_power = PSY.get_base_power(l),
        max_active_power = PSY.get_max_constant_active_power(l),
        max_reactive_power = PSY.get_max_constant_reactive_power(l),
    )
    remove_component!(sys, l)
    add_component!(sys, exp_load)
    return sys
end

function build_psid_load_tutorial_genrou(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = build_psid_load_tutorial_omib(; force_build = true, raw_data, sys_kwargs...)
    gen = get_component(ThermalStandard, sys, "generator-101-1")
    dyn_device = dyn_genrou(gen)
    add_component!(sys, dyn_device, gen)
    return sys
end

function build_psid_load_tutorial_droop(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = build_psid_load_tutorial_omib(; force_build = true, raw_data, sys_kwargs...)
    gen = get_component(ThermalStandard, sys, "generator-101-1")
    dyn_device = inv_droop(gen)
    add_component!(sys, dyn_device, gen)
    return sys
end

# IEEE 9-bus PCM time-series systems (data adapted from rodrigomha/IEEE9Bus-EPICS; see PSTD README)

function _ieee9_pcm_update_operation_cost!(sys, rts_sys)
    gen_names = ["generator-1-1", "generator-2-1", "generator-3-1"]
    rts_gen_names = ["101_STEAM_4", "213_CT_1", "321_CC_1"]
    fuel_types = [ThermalFuels.COAL, ThermalFuels.NATURAL_GAS, ThermalFuels.NATURAL_GAS]
    prime_movers = [PrimeMovers.ST, PrimeMovers.CT, PrimeMovers.CC]
    for (ix, gen_name) in enumerate(gen_names)
        gen = get_component(ThermalStandard, sys, gen_name)
        isnothing(gen) && continue
        rts_gen = get_component(ThermalStandard, rts_sys, rts_gen_names[ix])
        mid_slope = rts_gen.operation_cost.variable.value_curve.function_data.y_coords[2]
        fuel_cost = rts_gen.operation_cost.variable.fuel_cost
        new_op_cost = ThermalGenerationCost(;
            variable = CostCurve(;
                value_curve = LinearCurve(mid_slope * fuel_cost),
                power_units = rts_gen.operation_cost.variable.power_units,
                vom_cost = rts_gen.operation_cost.variable.vom_cost,
            ),
            fixed = rts_gen.operation_cost.fixed,
            start_up = rts_gen.operation_cost.start_up,
            shut_down = rts_gen.operation_cost.shut_down,
        )
        set_operation_cost!(gen, new_op_cost)
        set_prime_mover_type!(gen, prime_movers[ix])
        set_fuel!(gen, fuel_types[ix])
    end
    # RTS CT cold-start is cheaper than CC; raise Bus-2 start/shutdown to at least
    # Bus-3's so energy+commitment ranking keeps the expensive CT last.
    g2 = get_component(ThermalStandard, sys, "generator-2-1")
    g3 = get_component(ThermalStandard, sys, "generator-3-1")
    if !isnothing(g2) && !isnothing(g3)
        c2 = get_operation_cost(g2)
        c3 = get_operation_cost(g3)
        if c2.start_up < c3.start_up
            set_operation_cost!(
                g2,
                ThermalGenerationCost(;
                    variable = c2.variable,
                    fixed = c2.fixed,
                    start_up = c3.start_up,
                    shut_down = c3.shut_down,
                ),
            )
        end
    end
    return nothing
end

function _ieee9_pcm_add_load_time_series!(sys, rts_sys)
    load_names = ["load51", "load61", "load81"]
    rts_load_names = ["Alder", "Bacon", "Caesar"]
    for (ix, load_name) in enumerate(load_names)
        load = get_component(StandardLoad, sys, load_name)
        rts_load = get_component(PowerLoad, rts_sys, rts_load_names[ix])
        ts_array = get_time_series_array(
            SingleTimeSeries,
            rts_load,
            "max_active_power";
            ignore_scaling_factors = true,
        )
        add_time_series!(
            sys,
            load,
            SingleTimeSeries(;
                name = "max_active_power",
                data = ts_array,
                scaling_factor_multiplier = get_max_active_power,
            ),
        )
    end
    return nothing
end

# VSM GFM stack (inv_case78 / PSID case14 patterns from psidtest_library; inlined here).
function _ieee9_pcm_vsm_inverter(static_device)
    bus_kv = PSY.get_base_voltage(PSY.get_bus(static_device))
    return DynamicInverter(;
        name = PSY.get_name(static_device),
        ω_ref = 1.0,
        converter = AverageConverter(; rated_voltage = bus_kv, rated_current = 100.0),
        outer_control = OuterControl(
            VirtualInertia(; Ta = 2.0, kd = 400.0, kω = 20.0),
            ReactivePowerDroop(; kq = 0.2, ωf = 1000.0),
        ),
        inner_control = VoltageModeControl(;
            kpv = 0.59,
            kiv = 736.0,
            kffv = 0.0,
            rv = 0.0,
            lv = 0.2,
            kpc = 1.27,
            kic = 14.3,
            kffi = 0.0,
            ωad = 50.0,
            kad = 0.2,
        ),
        dc_source = FixedDCSource(; voltage = 600.0),
        freq_estimator = KauraPLL(; ω_lp = 500.0, kp_pll = 0.084, ki_pll = 4.69),
        filter = LCLFilter(; lf = 0.08, rf = 0.003, cf = 0.074, lg = 0.2, rg = 0.01),
        base_power = PSY.get_base_power(static_device),
    )
end

# Single A/B knob vs base: remove idle gen-2; add capped VSM GFM solar on bus 2 (coal REF stays).
const _IEEE9_PCM_GFM_RATING_MW = 100.0

function _ieee9_pcm_replace_gen2_with_gfm!(sys)
    gen2 = get_component(ThermalStandard, sys, "generator-2-1")
    isnothing(gen2) &&
        error("Expected ThermalStandard generator-2-1 in IEEE9 base RAW")
    # RAW parse is SYSTEM_BASE; NATURAL so getters return MW for P/Q limits.
    set_units_base_system!(sys, "NATURAL_UNITS")
    gen2_bus = get_bus(gen2)
    gen2_qlim = get_reactive_power_limits(gen2)
    gen2_p = min(get_active_power(gen2), _IEEE9_PCM_GFM_RATING_MW)
    gen2_dyn = get_dynamic_injector(gen2)
    !isnothing(gen2_dyn) && remove_component!(sys, gen2_dyn)
    remove_component!(sys, gen2)

    # Constructors store power fields in device base; use 100 MVA base so rating=1 → 100 MW.
    gfm_base = _IEEE9_PCM_GFM_RATING_MW
    gfm = RenewableDispatch(;
        name = "GFM_Bus_2",
        available = true,
        bus = gen2_bus,
        active_power = gen2_p / gfm_base,
        reactive_power = 0.0,
        rating = 1.0,
        prime_mover_type = PrimeMovers.PVe,
        reactive_power_limits = (
            min = gen2_qlim.min / gfm_base,
            max = gen2_qlim.max / gfm_base,
        ),
        power_factor = 1.0,
        operation_cost = RenewableGenerationCost(nothing),
        base_power = gfm_base,
    )
    add_component!(sys, gfm)
    add_component!(sys, _ieee9_pcm_vsm_inverter(gfm), gfm)
    return nothing
end

function _ieee9_pcm_add_gfm_time_series!(sys, rts_sys)
    gen = get_component(RenewableDispatch, sys, "GFM_Bus_2")
    isnothing(gen) && error("Expected RenewableDispatch GFM_Bus_2 after gen-2→GFM")
    rts_gen = get_component(RenewableDispatch, rts_sys, "101_PV_1")
    ts_array = get_time_series_array(
        SingleTimeSeries,
        rts_gen,
        "max_active_power";
        ignore_scaling_factors = true,
    )
    add_time_series!(
        sys,
        gen,
        SingleTimeSeries(;
            name = "max_active_power",
            data = ts_array,
            scaling_factor_multiplier = get_max_active_power,
        ),
    )
    return nothing
end

# PSS/E AREA ISW marks non-REF PV buses as ACBusTypes.SLACK. PSID/PowerFlows init maps
# only REF/PV/PQ into the PF bus-type priority dict, so convert orphan SLACK → PV.
function _ieee9_pcm_normalize_slack_buses!(sys)
    for bus in get_components(ACBus, sys)
        if get_bustype(bus) == ACBusTypes.SLACK
            set_bustype!(bus, ACBusTypes.PV)
        end
    end
    return nothing
end

function _ieee9_pcm_finalize_dynamics!(sys)
    _ieee9_pcm_normalize_slack_buses!(sys)
    for l in get_components(StandardLoad, sys)
        transform_load_to_constant_impedance(l)
    end
    return sys
end

function build_ieee9_bus_pcm_time_series(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    raw_file = joinpath(raw_data, "RTS_Esc487MW.raw")
    dyr_file = joinpath(raw_data, "RTS_CtrlsModified_STAB1.dyr")
    sys = System(raw_file, dyr_file; sys_kwargs...)
    rts_sys =
        build_system(PSISystems, "modified_RTS_GMLC_DA_sys_noForecast"; force_build = true)
    _ieee9_pcm_update_operation_cost!(sys, rts_sys)
    _ieee9_pcm_add_load_time_series!(sys, rts_sys)
    set_units_base_system!(sys, "NATURAL_UNITS")
    _ieee9_pcm_finalize_dynamics!(sys)
    return sys
end

function build_ieee9_bus_pcm_time_series_and_re(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    # Same parse path as base; GFM overlay is the only fleet difference.
    raw_file = joinpath(raw_data, "RTS_Esc487MW.raw")
    dyr_file = joinpath(raw_data, "RTS_CtrlsModified_STAB1.dyr")
    sys = System(raw_file, dyr_file; sys_kwargs...)
    _ieee9_pcm_replace_gen2_with_gfm!(sys)
    rts_sys =
        build_system(PSISystems, "modified_RTS_GMLC_DA_sys_noForecast"; force_build = true)
    _ieee9_pcm_update_operation_cost!(sys, rts_sys)
    _ieee9_pcm_add_load_time_series!(sys, rts_sys)
    _ieee9_pcm_add_gfm_time_series!(sys, rts_sys)
    set_units_base_system!(sys, "NATURAL_UNITS")
    _ieee9_pcm_finalize_dynamics!(sys)
    return sys
end
