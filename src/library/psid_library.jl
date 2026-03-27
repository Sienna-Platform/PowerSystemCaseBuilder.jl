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
        base_power = PSY._get_base_power(l),
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
