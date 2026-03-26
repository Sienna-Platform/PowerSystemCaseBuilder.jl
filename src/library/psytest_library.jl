function build_tamu_ACTIVSg2000_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "ACTIVSg2000", "ACTIVSg2000.RAW")
    !isfile(file_path) && throw(DataFormatError("Cannot find $file_path"))

    pm_data = PowerFlowFileParser.PowerModelsData(file_path)

    bus_name_formatter =
        get(
            sys_kwargs,
            :bus_name_formatter,
            x -> string(x["name"]) * "-" * string(x["index"]),
        )
    load_name_formatter =
        get(sys_kwargs, :load_name_formatter, x -> strip(join(x["source_id"], "_")))

    # make system
    sys = PSY.System(
        pm_data;
        bus_name_formatter = bus_name_formatter,
        load_name_formatter = load_name_formatter,
        sys_kwargs...,
    )

    # add time_series
    header_row = 2

    tamu_files = readdir(joinpath(raw_data, "ACTIVSg2000"))
    load_file = joinpath(
        joinpath(raw_data, "ACTIVSg2000"),
        tamu_files[occursin.("_load_time_series_MW.csv", tamu_files)][1],
    ) # currently only adding MW load time_series

    !isfile(load_file) && throw(DataFormatError("Cannot find $load_file"))

    header = String.(split(open(readlines, load_file)[header_row], ","))
    fixed_cols = ["Date", "Time", "Num Load", "Total MW Load", "Total Mvar Load"]

    # value columns have the format "Bus 1001 #1 MW", we want "load_1001_1"
    for load in header
        load in fixed_cols && continue
        lsplit = split(replace(string(load), "#" => ""), " ")
        @assert length(lsplit) == 4
        push!(fixed_cols, "load_" * join(lsplit[2:3], "_"))
    end

    loads = DataFrames.DataFrame(
        CSV.File(load_file; skipto = 3, header = fixed_cols);
        copycols = false,
    )

    function parse_datetime_ampm(ds::AbstractString, fmt::Dates.DateFormat)
        m = match(r"(.*)\s(AM|PM)", ds)
        d = Dates.DateTime(m.captures[1], fmt)
        ampm = uppercase(something(m.captures[2], ""))
        d + Dates.Hour(12 * +(ampm == "PM", ampm == "" || Dates.hour(d) != 12, -1))
    end

    dfmt = Dates.DateFormat("m/dd/yyy H:M:S")

    loads[!, :timestamp] =
        parse_datetime_ampm.(string.(loads[!, :Date], " ", loads[!, :Time]), dfmt)

    for lname in setdiff(
        names(loads),
        [
            :timestamp,
            :Date,
            :Time,
            Symbol("Num Load"),
            Symbol("Total MW Load"),
            Symbol("Total Mvar Load"),
        ],
    )
        component = PSY.get_component(PSY.PowerLoad, sys, string(lname))
        if !isnothing(component)
            ts = PSY.SingleTimeSeries(
                "max_active_power",
                loads[!, ["timestamp", lname]];
                normalization_factor = Float64(maximum(loads[!, lname])),
                scaling_factor_multiplier = PSY.get_max_active_power,
            )
            PSY.add_time_series!(sys, component, ts)
        end
    end

    return sys
end

function build_psse_Benchmark_4ger_33_2015_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "psse_raw", "Benchmark_4ger_33_2015.RAW")
    dyr_file = joinpath(raw_data, "psse_dyr", "Benchmark_4ger_33_2015.dyr")
    sys = PSY.System(file_path, dyr_file; sys_kwargs...)
    return sys
end

function build_psse_OMIB_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "psse_raw", "OMIB.raw")
    dyr_file = joinpath(raw_data, "psse_dyr", "OMIB.dyr")
    sys = PSY.System(file_path, dyr_file; sys_kwargs...)
    return sys
end

function build_psse_3bus_gen_cls_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "psse_raw", "ThreeBusNetwork.raw")
    dyr_file = joinpath(raw_data, "psse_dyr", "TestGENCLS.dyr")
    sys = PSY.System(file_path, dyr_file; sys_kwargs...)
    return sys
end

function psse_renewable_parsing_1(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "psse_raw", "Benchmark_4ger_33_2015_RENA.RAW")
    dyr_file = joinpath(raw_data, "psse_dyr", "Benchmark_4ger_33_2015_RENA.dyr")
    sys = PSY.System(file_path, dyr_file; sys_kwargs...)
    return sys
end

function build_psse_3bus_sexs_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "psse_raw", "ThreeBusNetwork.raw")
    dyr_file = joinpath(raw_data, "psse_dyr", "test_SEXS.dyr")
    sys = PSY.System(file_path, dyr_file; sys_kwargs...)
    return sys
end

function build_psse_original_240_case(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "psse_raw", "240busWECC_2018_PSS33.raw")
    dyr_file = joinpath(raw_data, "psse_dyr", "240busWECC_2018_PSS.dyr")
    sys = PSY.System(
        file_path,
        dyr_file;
        bus_name_formatter = x -> string(x["name"]) * "-" * string(x["index"]),
        sys_kwargs...,
    )
    return sys
end

function build_psse_3bus_no_cls_sys(; raw_data, kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    file_path = joinpath(raw_data, "psse_raw", "ThreeBusNetwork.raw")
    dyr_file = joinpath(raw_data, "psse_dyr", "Test-NoCLS.dyr")
    sys = PSY.System(file_path, dyr_file; sys_kwargs...)
    return sys
end

function build_dynamic_inverter_sys(; kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    nodes_OMIB = [
        PSY.ACBus(
            1, #number
            "Bus 1", #Name
            true, #available
            "REF", #BusType (REF, PV, PQ)
            0, #Angle in radians
            1.06, #Voltage in pu
            (min = 0.94, max = 1.06), #Voltage limits in pu
            69,
            nothing,
            nothing,
        ), #Base voltage in kV
        PSY.ACBus(
            2,
            "Bus 2",
            true, #available
            "PV",
            0,
            1.045,
            (min = 0.94, max = 1.06),
            69,
            nothing,
            nothing,
        ),
    ]

    battery = PSY.EnergyReservoirStorage(;
        name = "Battery",
        prime_mover_type = PSY.PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        available = true,
        bus = nodes_OMIB[2],
        storage_capacity = 100.0,
        storage_level_limits = (min = 5.0 / 100.0, max = 100.0 / 100.0),
        initial_storage_capacity_level = 5.0 / 100.0,
        rating = 0.0275, #Value in per_unit of the system
        active_power = 0.01375,
        input_active_power_limits = (min = 0.0, max = 50.0),
        output_active_power_limits = (min = 0.0, max = 50.0),
        reactive_power = 0.0,
        reactive_power_limits = (min = -50.0, max = 50.0),
        efficiency = (in = 0.80, out = 0.90),
        base_power = 100.0,
    )
    converter = PSY.AverageConverter(
        138.0, #Rated Voltage
        100.0,
    ) #Rated MVA

    branch_OMIB = [
        PSY.Line(
            "Line1", #name
            true, #available
            0.0, #active power flow initial condition (from-to)
            0.0, #reactive power flow initial condition (from-to)
            Arc(; from = nodes_OMIB[1], to = nodes_OMIB[2]), #Connection between buses
            0.01, #resistance in pu
            0.05, #reactance in pu
            (from = 0.0, to = 0.0), #susceptance in pu
            18.046, #rating in MW
            1.04,
        ),
    ]  #angle limits (-min and max)

    dc_source = PSY.FixedDCSource(1500.0) #Not in the original data, guessed.

    filt = PSY.LCLFilter(
        0.08, #Series inductance lf in pu
        0.003, #Series resitance rf in pu
        0.074, #Shunt capacitance cf in pu
        0.2, #Series reactance rg to grid connection (#Step up transformer or similar)
        0.01,
    ) #Series resistance lg to grid connection (#Step up transformer or similar)

    pll = PSY.KauraPLL(
        500.0, #ω_lp: Cut-off frequency for LowPass filter of PLL filter.
        0.084, #k_p: PLL proportional gain
        4.69,
    ) #k_i: PLL integral gain

    virtual_H = PSY.VirtualInertia(
        2.0, #Ta:: VSM inertia constant
        400.0, #kd:: VSM damping coefficient
        20.0, #kω:: Frequency droop gain in pu
        2 * pi * 50.0,
    ) #ωb:: Rated angular frequency

    Q_control = PSY.ReactivePowerDroop(
        0.2, #kq:: Reactive power droop gain in pu
        1000.0,
    ) #ωf:: Reactive power cut-off low pass filter frequency

    outer_control = PSY.OuterControl(virtual_H, Q_control)

    vsc = PSY.VoltageModeControl(
        0.59, #kpv:: Voltage controller proportional gain
        736.0, #kiv:: Voltage controller integral gain
        0.0, #kffv:: Binary variable enabling the voltage feed-forward in output of current controllers
        0.0, #rv:: Virtual resistance in pu
        0.2, #lv: Virtual inductance in pu
        1.27, #kpc:: Current controller proportional gain
        14.3, #kiv:: Current controller integral gain
        0.0, #kffi:: Binary variable enabling the current feed-forward in output of current controllers
        50.0, #ωad:: Active damping low pass filter cut-off frequency
        0.2,
    ) #kad:: Active damping gain

    sys = PSY.System(100)
    for bus in nodes_OMIB
        PSY.add_component!(sys, bus)
    end
    for lines in branch_OMIB
        PSY.add_component!(sys, lines)
    end
    PSY.add_component!(sys, battery)

    test_inverter = PSY.DynamicInverter(
        PSY.get_name(battery),
        1.0, #ω_ref
        converter, #Converter
        outer_control, #OuterControl
        vsc, #Voltage Source Controller
        dc_source, #DC Source
        pll, #Frequency Estimator
        filt,
    ) #Output Filter

    PSY.add_component!(sys, test_inverter, battery)

    return sys
end
