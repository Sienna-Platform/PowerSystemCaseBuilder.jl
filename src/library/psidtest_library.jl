function transform_load_to_constant_impedance(load::PSY.StandardLoad)
    # Total Load Calculations
    active_power, reactive_power, max_active_power, max_reactive_power =
        _compute_total_load_parameters(load)
    # Set Impedance Power
    PSY.set_impedance_active_power!(load, active_power)
    PSY.set_impedance_reactive_power!(load, reactive_power)
    PSY.set_max_impedance_active_power!(load, max_active_power)
    PSY.set_max_impedance_reactive_power!(load, max_reactive_power)
    # Set everything else to zero
    PSY.set_constant_active_power!(load, 0.0)
    PSY.set_constant_reactive_power!(load, 0.0)
    PSY.set_max_constant_active_power!(load, 0.0)
    PSY.set_max_constant_reactive_power!(load, 0.0)
    PSY.set_current_active_power!(load, 0.0)
    PSY.set_current_reactive_power!(load, 0.0)
    PSY.set_max_current_active_power!(load, 0.0)
    PSY.set_max_current_reactive_power!(load, 0.0)
    return
end

function _compute_total_load_parameters(load::PSY.StandardLoad)
    @warn "Load data is transformed under the assumption of a 1.0 p.u. Voltage Magnitude"
    # Constant Power Data
    constant_active_power = PSY.get_constant_active_power(load)
    constant_reactive_power = PSY.get_constant_reactive_power(load)
    max_constant_active_power = PSY.get_max_constant_active_power(load)
    max_constant_reactive_power = PSY.get_max_constant_reactive_power(load)
    # Constant Current Data
    current_active_power = PSY.get_current_active_power(load)
    current_reactive_power = PSY.get_current_reactive_power(load)
    max_current_active_power = PSY.get_max_current_active_power(load)
    max_current_reactive_power = PSY.get_max_current_reactive_power(load)
    # Constant Admittance Data
    impedance_active_power = PSY.get_impedance_active_power(load)
    impedance_reactive_power = PSY.get_impedance_reactive_power(load)
    max_impedance_active_power = PSY.get_max_impedance_active_power(load)
    max_impedance_reactive_power = PSY.get_max_impedance_reactive_power(load)
    # Total Load Calculations
    active_power = constant_active_power + current_active_power + impedance_active_power
    reactive_power =
        constant_reactive_power + current_reactive_power + impedance_reactive_power
    max_active_power =
        max_constant_active_power + max_current_active_power + max_impedance_active_power
    max_reactive_power =
        max_constant_reactive_power +
        max_current_reactive_power +
        max_impedance_reactive_power
    return active_power, reactive_power, max_active_power, max_reactive_power
end

function build_psid_psse_test_avr(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    avr_type = get(kwargs, :avr_type, "")
    if isempty(avr_type)
        @warn(
            "No AVR type provided. Provide avr_type as kwarg when using build_system. By default AC1A will be used."
        )
        avr_type = "AC1A"
    end
    if avr_type == "AC1A_SAT"
        raw_file = joinpath(raw_data, "AC1A/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "AC1A/ThreeBus_ESAC1A_SAT.dyr")
    elseif avr_type == "AC1A"
        raw_file = joinpath(raw_data, "AC1A/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "AC1A/ThreeBus_ESAC1A.dyr")
    elseif avr_type == "EXAC1" || avr_type == "EXST1"
        raw_file = joinpath(raw_data, avr_type, "TVC_System_32.raw")
        dyr_file = joinpath(raw_data, avr_type, "TVC_System.dyr")
    elseif avr_type == "SEXS"
        raw_file = joinpath(raw_data, "SEXS/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "SEXS/ThreeBus_SEXS.dyr")
    elseif avr_type == "SEXS_noTE"
        raw_file = joinpath(raw_data, "SEXS/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "SEXS/ThreeBus_SEXS_noTE.dyr")
    else
        error(
            "Kwarg avr_type = $(avr_type) for PSID/PSSE test not supported. Available kwargs are: $(AVAILABLE_PSID_PSSE_AVRS_TEST)",
        )
    end
    avr_sys = System(raw_file, dyr_file; sys_kwargs...)
    for l in get_components(PSY.PowerLoad, avr_sys)
        PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
    end
    return avr_sys
end

function build_psid_psse_test_tg(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    tg_type = get(kwargs, :tg_type, "")
    if isempty(tg_type)
        @warn(
            "No Turbine Governor type provided. Provide tg_type as kwarg when using build_system. By default GAST will be used.",
        )
        tg_type = "GAST"
    end
    if tg_type == "GAST"
        raw_file = joinpath(raw_data, "GAST/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "GAST/ThreeBus_GAST.dyr")
    elseif tg_type == "HYGOV"
        raw_file = joinpath(raw_data, "HYGOV/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "HYGOV/ThreeBus_HYGOV.dyr")
    elseif tg_type == "TGOV1"
        raw_file = joinpath(raw_data, "TGOV1/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "TGOV1/ThreeBus_TGOV1.dyr")
    else
        error(
            "Kwarg tg_type = $(tg_type) for PSID/PSSE test not supported. Available kwargs are: $(AVAILABLE_PSID_PSSE_TGS_TEST)",
        )
    end
    tg_sys = System(raw_file, dyr_file; sys_kwargs...)

    for l in get_components(PSY.StandardLoad, tg_sys)
        transform_load_to_constant_impedance(l)
    end

    return tg_sys
end

function build_psid_psse_test_gen(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    gen_type = get(kwargs, :gen_type, "")
    if isempty(gen_type)
        @warn(
            "No Generator model type provided. Provide gen_type as kwarg when using build_system. By default GENCLS will be used.",
        )
        gen_type = "GENCLS"
    end
    if gen_type == "GENCLS"
        raw_file = joinpath(raw_data, "GENCLS/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "GENCLS/ThreeBus_GENCLS.dyr")
    elseif gen_type == "GENROE"
        raw_file = joinpath(raw_data, "GENROE/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "GENROE/ThreeBus_GENROE.dyr")
    elseif gen_type == "GENROE_SAT"
        raw_file = joinpath(raw_data, "GENROE/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "GENROE/ThreeBus_GENROE_HIGH_SAT.dyr")
    elseif gen_type == "GENROU"
        raw_file = joinpath(raw_data, "GENROU/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "GENROU/ThreeBus_GENROU.dyr")
    elseif gen_type == "GENROU_NoSAT"
        raw_file = joinpath(raw_data, "GENROU/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "GENROU/ThreeBus_GENROU_NO_SAT.dyr")
    elseif gen_type == "GENROU_SAT"
        raw_file = joinpath(raw_data, "GENROU/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "GENROU/ThreeBus_GENROU_HIGH_SAT.dyr")
    elseif gen_type == "GENSAE"
        raw_file = joinpath(raw_data, "GENSAE/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "GENSAE/ThreeBus_GENSAE.dyr")
    elseif gen_type == "GENSAL"
        raw_file = joinpath(raw_data, "GENSAL/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "GENSAL/ThreeBus_GENSAL.dyr")
    else
        error(
            "Kwarg gen_type = $(gen_type) for PSID/PSSE test not supported. Available kwargs are: $(AVAILABLE_PSID_PSSE_GENS_TEST)",
        )
    end
    gen_sys = System(raw_file, dyr_file; sys_kwargs...)

    for l in get_components(PSY.StandardLoad, gen_sys)
        transform_load_to_constant_impedance(l)
    end

    return gen_sys
end

function build_psid_psse_test_pss(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    pss_type = get(kwargs, :pss_type, "")
    if isempty(pss_type)
        @warn(
            "No PSS type provided. Provide pss_type as kwarg when using build_system. By default STAB1 will be used."
        )
        pss_type = "STAB1"
    end
    if pss_type == "STAB1"
        raw_file = joinpath(raw_data, "STAB1/OMIB_SSS.raw")
        dyr_file = joinpath(raw_data, "STAB1/OMIB_SSS.dyr")
    elseif pss_type == "IEEEST"
        raw_file = joinpath(raw_data, "IEEEST/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "IEEEST/ThreeBus_IEEEST.dyr")
    elseif pss_type == "IEEEST_FILTER"
        raw_file = joinpath(raw_data, "IEEEST/ThreeBusMulti.raw")
        dyr_file = joinpath(raw_data, "IEEEST/ThreeBus_IEEEST_with_filter.dyr")
    else
        error(
            "Kwarg tg_type = $(pss_type) for PSID/PSSE test not supported. Available kwargs are: $(AVAILABLE_PSID_PSSE_PSS_TEST)",
        )
    end
    pss_sys = System(raw_file, dyr_file; sys_kwargs...)

    for l in get_components(PSY.StandardLoad, pss_sys)
        transform_load_to_constant_impedance(l)
    end

    return pss_sys
end

function build_psid_test_omib(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    omib_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(omib_sys)

    function dyn_gen_classic(generator)
        return DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_classic(),
            shaft = shaft_damping(),
            avr = avr_none(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    gen = [g for g in get_components(Generator, omib_sys)][1]
    case_gen = dyn_gen_classic(gen)
    add_component!(omib_sys, case_gen, gen)

    for l in get_components(PSY.StandardLoad, omib_sys)
        transform_load_to_constant_impedance(l)
    end

    return omib_sys
end

function build_psid_test_threebus_oneDoneQ(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(threebus_sys)

    function dyn_gen_oneDoneQ(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_oneDoneQ(),
            shaft = shaft_no_damping(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    for g in get_components(Generator, threebus_sys)
        case_gen = dyn_gen_oneDoneQ(g)
        add_component!(threebus_sys, case_gen, g)
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    return threebus_sys
end

function build_psid_test_threebus_simple_marconato(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(threebus_sys)

    function dyn_gen_simple_marconato(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_simple_marconato(),
            shaft = shaft_no_damping(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    for g in get_components(Generator, threebus_sys)
        case_gen = dyn_gen_simple_marconato(g)
        add_component!(threebus_sys, case_gen, g)
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    return threebus_sys
end

function build_psid_test_threebus_marconato(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(threebus_sys)

    function dyn_gen_marconato(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_marconato(),
            shaft = shaft_no_damping(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    for g in get_components(Generator, threebus_sys)
        case_gen = dyn_gen_marconato(g)
        add_component!(threebus_sys, case_gen, g)
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    return threebus_sys
end

function build_psid_test_threebus_simple_anderson(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(threebus_sys)

    function dyn_gen_simple_anderson(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_simple_anderson(),
            shaft = shaft_no_damping(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    for g in get_components(Generator, threebus_sys)
        case_gen = dyn_gen_simple_anderson(g)
        add_component!(threebus_sys, case_gen, g)
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    return threebus_sys
end

function build_psid_test_threebus_anderson(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(threebus_sys)

    function dyn_gen_anderson(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_anderson(),
            shaft = shaft_no_damping(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    for g in get_components(Generator, threebus_sys)
        case_gen = dyn_gen_anderson(g)
        add_component!(threebus_sys, case_gen, g)
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    return threebus_sys
end

function build_psid_test_threebus_5shaft(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(threebus_sys)

    #Reduce generator output
    for g in get_components(Generator, threebus_sys)
        g.active_power = 0.75
    end

    function dyn_gen_five_mass_shaft_order(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_oneDoneQ(),
            shaft = shaft_fivemass(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    function dyn_gen_first_order(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_oneDoneQ(),
            shaft = shaft_damping(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    for g in get_components(Generator, threebus_sys)
        if get_number(get_bus(g)) == 103
            case_gen = dyn_gen_five_mass_shaft_order(g)
            add_component!(threebus_sys, case_gen, g)
        elseif get_number(get_bus(g)) == 102
            case_inv = dyn_gen_first_order(g)
            add_component!(threebus_sys, case_inv, g)
        end
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    return threebus_sys
end

function build_psid_test_vsm_inverter(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    omib_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(omib_sys)

    function inv_darco(static_device)
        return PSY.DynamicInverter(
            PSY.get_name(static_device),
            1.0,
            converter_low_power(),
            outer_control(),
            inner_control(),
            dc_source_lv(),
            pll(),
            filt(),
        ) #pss
    end

    for l in get_components(PSY.StandardLoad, omib_sys)
        transform_load_to_constant_impedance(l)
    end

    #Attach dynamic generator. Currently use PSS/e format based on bus #.
    device = [g for g in get_components(Generator, omib_sys)][1]
    case_inv = inv_darco(device)
    add_component!(omib_sys, case_inv, device)

    return omib_sys
end

function build_psid_test_threebus_machine_vsm(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(threebus_sys)

    function dyn_gen_second_order(generator)
        return DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_oneDoneQ(),
            shaft = shaft_no_damping(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    function inv_case78(static_device)
        return DynamicInverter(;
            name = PSY.get_name(static_device),
            ω_ref = 1.0,
            converter = converter_high_power(),
            outer_control = outer_control(),
            inner_control = inner_control(),
            dc_source = dc_source_lv(),
            freq_estimator = pll(),
            filter = filt(),
        )
    end

    for g in get_components(Generator, threebus_sys)
        if get_number(get_bus(g)) == 102
            case_gen = dyn_gen_second_order(g)
            add_component!(threebus_sys, case_gen, g)
        elseif get_number(get_bus(g)) == 103
            case_inv = inv_case78(g)
            add_component!(threebus_sys, case_inv, g)
        end
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    return threebus_sys
end

function build_psid_test_threebus_machine_vsm_dynlines(; kwargs...)
    threebus_sys = build_psid_test_threebus_machine_vsm(; kwargs...)
    dyn_branch = DynamicBranch(get_component(Branch, threebus_sys, "BUS 2-BUS 3-i_1"))
    add_component!(threebus_sys, dyn_branch)

    return threebus_sys
end

function build_psid_test_threebus_multimachine(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)

    function dyn_gen_multi(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_classic(),
            shaft = shaft_damping(),
            avr = avr_none(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    function dyn_gen_multi_tg(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_classic(),
            shaft = shaft_damping(),
            avr = avr_none(),
            prime_mover = tg_type2(),
            pss = pss_none(),
        )
    end

    for g in get_components(Generator, threebus_sys)
        if get_number(get_bus(g)) == 101
            case_gen = dyn_gen_multi(g)
            add_component!(threebus_sys, case_gen, g)
        elseif get_number(get_bus(g)) == 102
            case_gen = dyn_gen_multi_tg(g)
            add_component!(threebus_sys, case_gen, g)
        end
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    return threebus_sys
end

function build_psid_test_threebus_psat_avrs(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(threebus_sys)

    function dyn_gen_avr_type2(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_oneDoneQ(),
            shaft = shaft_no_damping(),
            avr = avr_type2(),
            prime_mover = tg_type1(),
            pss = pss_none(),
        )
    end

    function dyn_gen_simple_avr(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_oneDoneQ(),
            shaft = shaft_no_damping(),
            avr = avr_propr(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    for g in get_components(Generator, threebus_sys)
        if get_number(get_bus(g)) == 102
            case_gen = dyn_gen_avr_type2(g)
            add_component!(threebus_sys, case_gen, g)
        elseif get_number(get_bus(g)) == 103
            case_gen = dyn_gen_simple_avr(g)
            add_component!(threebus_sys, case_gen, g)
        end
    end

    return threebus_sys
end

function build_psid_test_threebus_vsm_reference(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    threebus_sys = System(raw_data; runchecks = false, sys_kwargs...)

    function inv_case78(static_device)
        return DynamicInverter(;
            name = PSY.get_name(static_device),
            ω_ref = 1.0, # ω_ref,
            converter = converter_high_power(),
            outer_control = outer_control(),
            inner_control = inner_control(),
            dc_source = dc_source_lv(),
            freq_estimator = pll(),
            filter = filt(),
        )
    end

    function dyn_gen_multi_tg(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_classic(),
            shaft = shaft_damping(),
            avr = avr_none(),
            prime_mover = tg_type2(),
            pss = pss_none(),
        )
    end

    for g in get_components(Generator, threebus_sys)
        if get_number(get_bus(g)) == 101
            case_gen = inv_case78(g)
            add_component!(threebus_sys, case_gen, g)
        elseif get_number(get_bus(g)) == 102
            case_gen = dyn_gen_multi_tg(g)
            add_component!(threebus_sys, case_gen, g)
        end
    end

    for l in get_components(PSY.StandardLoad, threebus_sys)
        transform_load_to_constant_impedance(l)
    end

    return threebus_sys
end

function build_psid_test_threebus_genrou_avr(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = System(raw_data; runchecks = false, sys_kwargs...)

    #Replace Gen101 by Source
    remove_component!(ThermalStandard, sys, "generator-101-1")
    add_source_to_ref(sys)

    function dyn_gen_genrou(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_genrou(),
            shaft = shaft_genrou(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    for l in get_components(PSY.StandardLoad, sys)
        transform_load_to_constant_impedance(l)
    end

    #Add GENROU to System
    g = get_component(ThermalStandard, sys, "generator-102-1")
    dyn_gen = dyn_gen_genrou(g)
    add_component!(sys, dyn_gen, g)

    return sys
end

function build_psid_test_droop_inverter(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    omib_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(omib_sys)

    ############### Data Dynamic devices ########################
    function inv_darco_droop(static_device)
        return PSY.DynamicInverter(
            PSY.get_name(static_device),
            1.0, # ω_ref
            converter_low_power(), # converter
            outer_control_droop(), # outer control
            inner_control(), # inner control
            dc_source_lv(), # dc source
            no_pll(), # no pll
            filt(), # filter
        )
    end

    for l in get_components(PSY.StandardLoad, omib_sys)
        transform_load_to_constant_impedance(l)
    end

    device = [g for g in get_components(Generator, omib_sys)][1]
    case_inv = inv_darco_droop(device)
    add_component!(omib_sys, case_inv, device)

    return omib_sys
end

function build_psid_test_gfoll_inverter(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    omib_sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(omib_sys)

    ############### Data Dynamic devices ########################
    function inv_gfoll(static_device)
        return PSY.DynamicInverter(
            PSY.get_name(static_device),
            1.0, # ω_ref
            converter_low_power(), # converter
            outer_control_gfoll(), # outercontrol
            current_mode_inner(), # inner_control
            dc_source_lv(), # dc source
            reduced_pll(), # pll
            filt_gfoll(), # filter
        )
    end

    for l in get_components(PSY.StandardLoad, omib_sys)
        transform_load_to_constant_impedance(l)
    end

    device = [g for g in get_components(Generator, omib_sys)][1]
    case_inv = inv_gfoll(device)
    add_component!(omib_sys, case_inv, device)

    return omib_sys
end

function build_psid_test_threebus_multimachine_dynlines(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = System(raw_data; runchecks = false, sys_kwargs...)

    ############### Data Dynamic devices ########################
    function dyn_gen_marconato(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_marconato(),
            shaft = shaft_no_damping(),
            avr = AVRSimple(1.0),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    function dyn_gen_marconato_tg(generator)
        return PSY.DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_marconato(),
            shaft = shaft_no_damping(),
            avr = AVRSimple(1.0),
            prime_mover = tg_type2(),
            pss = pss_none(),
        )
    end

    # Add dynamic generators to the system (each gen is linked through a static one)
    for g in get_components(Generator, sys)
        if get_number(get_bus(g)) == 101
            case_gen = dyn_gen_marconato_tg(g)
            add_component!(sys, case_gen, g)
        elseif get_number(get_bus(g)) == 102
            case_gen = dyn_gen_marconato(g)
            add_component!(sys, case_gen, g)
        end
    end

    # Transform all lines into dynamic lines
    for line in collect(get_components(Line, sys))
        dyn_line = DynamicBranch(line)
        add_component!(sys, dyn_line)
    end

    for l in get_components(PSY.StandardLoad, sys)
        transform_load_to_constant_impedance(l)
    end

    return sys
end

function build_psid_test_pvs(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    sys = System(raw_data; runchecks = false, sys_kwargs...)
    add_source_to_ref(sys)

    ############### Data Dynamic devices ########################
    function pvs_simple(source)
        return PeriodicVariableSource(;
            name = PSY.get_name(source),
            R_th = PSY.get_R_th(source),
            X_th = PSY.get_X_th(source),
            internal_voltage_bias = 1.0,
            internal_voltage_frequencies = [2 * pi],
            internal_voltage_coefficients = [(1.0, 0.0)],
            internal_angle_bias = 0.0,
            internal_angle_frequencies = [2 * pi],
            internal_angle_coefficients = [(0.0, 1.0)],
        )
    end

    function dyn_gen_second_order(generator)
        return DynamicGenerator(;
            name = PSY.get_name(generator),
            ω_ref = 1.0,
            machine = machine_oneDoneQ(),
            shaft = shaft_no_damping(),
            avr = avr_type1(),
            prime_mover = tg_none(),
            pss = pss_none(),
        )
    end

    #Attach dynamic generator
    gen = [g for g in get_components(Generator, sys)][1]
    case_gen = dyn_gen_second_order(gen)
    add_component!(sys, case_gen, gen)

    #Attach periodic variable source
    source = [s for s in get_components(Source, sys)][1]
    pvs = pvs_simple(source)
    add_component!(sys, pvs, source)

    for l in get_components(PSY.StandardLoad, sys)
        transform_load_to_constant_impedance(l)
    end

    return sys
end

###########################
# Add Test 29 systems here
###########################

function build_psid_test_ieee_9bus(; raw_data, kwargs...)
    return System(raw_data)
end

function build_psid_psse_test_constantP_load(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    raw_file = joinpath(raw_data, "ThreeBusMulti.raw")
    dyr_file = joinpath(raw_data, "ThreeBus_GENROU.dyr")
    sys = System(raw_file, dyr_file; sys_kwargs...)
    return sys
end

function build_psid_psse_test_constantI_load(; kwargs...)
    sys = build_psid_psse_test_constantP_load(; kwargs...)
    for l in get_components(PSY.PowerLoad, sys)
        PSY.set_model!(l, PSY.LoadModels.ConstantCurrent)
    end
    return sys
end

function build_psid_psse_test_exp_load(; kwargs...)
    sys = build_psid_psse_test_constantP_load(; kwargs...)
    for l in collect(get_components(PSY.PowerLoad, sys))
        exp_load = PSY.ExponentialLoad(;
            name = PSY.get_name(l),
            available = PSY.get_available(l),
            bus = PSY.get_bus(l),
            active_power = PSY.get_active_power(l, Float64),
            reactive_power = PSY.get_reactive_power(l, Float64),
            active_power_coefficient = 0.0, # Constant Power
            reactive_power_coefficient = 0.0, # Constant Power
            base_power = PSY._get_base_power(l),
            max_active_power = PSY.get_max_active_power(l, Float64),
            max_reactive_power = PSY.get_max_reactive_power(l, Float64),
        )
        PSY.remove_component!(sys, l)
        PSY.add_component!(sys, exp_load)
    end
    return sys
end

function build_psid_test_indmotor(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    raw_file = joinpath(raw_data, "TVC_System_motor.raw")
    dyr_file = joinpath(raw_data, "TVC_System_motor.dyr")
    sys = System(raw_file, dyr_file; sys_kwargs...)
    return sys
end

function build_psid_test_5th_indmotor(; kwargs...)
    sys = build_psid_test_indmotor(; kwargs...)
    load = first(get_components(PSY.ElectricLoad, sys))
    # Include the induction motor
    dynamic_injector = Ind_Motor(load)
    add_component!(sys, dynamic_injector, load)
    return sys
end

function build_psid_test_3rd_indmotor(; kwargs...)
    sys = build_psid_test_indmotor(; kwargs...)
    load = first(get_components(PSY.ElectricLoad, sys))
    # Include the induction motor
    dynamic_injector = Ind_Motor3rd(load)
    add_component!(sys, dynamic_injector, load)
    return sys
end
