"""
Constructs a System from PowerFlowFileParser.PowerModelsData.

# Arguments
- `pm_data::Union{PowerFlowFileParser.PowerModelsData, Union{String, IO}}`: PowerFlowFileParser.PowerModels 
data object or supported load flow case (*.m, *.raw)

# Keyword arguments
- `ext::Dict`: Contains user-defined parameters. Should only contain standard types.
- `runchecks::Bool`: Run available checks on input fields and when add_component! is called.
  Throws InvalidValue if an error is found.
- `time_series_in_memory::Bool=false`: Store time series data in memory instead of HDF5.
- `config_path::String`: specify path to validation config file
- `pm_data_corrections::Bool=true` : Run the PowerModels data corrections (aka :validate in PowerModels)
- `import_all:Bool=false` : Import all fields from PTI files

# Examples
```julia
sys = System(
    pm_data, config_path = "ACTIVSg25k_validation.json",
    bus_name_formatter = x->string(x["name"]*"-"*string(x["index"])),
    load_name_formatter = x->strip(join(x["source_id"], "_"))
)
```
"""
function make_system(pm_data::PowerFlowFileParser.PowerModelsData; kwargs...)
    runchecks = get(kwargs, :runchecks, true)
    data = pm_data.data
    if length(data["bus"]) < 1
        throw(DataFormatError("There are no buses in this file."))
    end

    @info "Constructing System from Power Models" data["name"] data["source_type"]

    sys_kwargs = filter_kwargs(; kwargs...)
    sys = System(data["baseMVA"]; sys_kwargs...)

    source_type = data["source_type"]

    bus_number_to_bus = read_bus!(sys, data; kwargs...)
    read_loads!(sys, data, bus_number_to_bus; kwargs...)
    read_loadzones!(sys, data, bus_number_to_bus; kwargs...)
    read_gen!(sys, data, bus_number_to_bus; kwargs...)
    for component_type in ["switch", "breaker"]
        read_switch_breaker!(sys, data, bus_number_to_bus, component_type; kwargs...)
    end
    read_branch!(sys, data, bus_number_to_bus; kwargs...)
    read_switched_shunt!(sys, data, bus_number_to_bus; kwargs...)
    read_shunt!(sys, data, bus_number_to_bus; kwargs...)
    read_dcline!(sys, data, bus_number_to_bus, source_type; kwargs...)
    read_vscline!(sys, data, bus_number_to_bus; kwargs...)
    read_facts!(sys, data, bus_number_to_bus; kwargs...)
    read_storage!(sys, data, bus_number_to_bus; kwargs...)
    read_3w_transformer!(sys, data, bus_number_to_bus; kwargs...)
    if runchecks
        check(sys)
    end

    substation_data = get(data, "substation_data", [])
    add_geographic_info_to_buses!(sys, substation_data)

    return sys
end

"""
Construct a System from a PSS/E raw file via the PowerModels dict pipeline. Thin shim
over [`make_system`](@ref); the metadata-reimport path threads its name-formatter kwargs
through it.
"""
function system_via_power_models(file_path::AbstractString; kwargs...)
    return make_system(PowerFlowFileParser.PowerModelsData(file_path); kwargs...)
end

"""
Internal component name retrieval from pm2ps_dict
"""
function _get_pm_dict_name(device_dict::Dict)::String
    if haskey(device_dict, "shunt_bus")
        # With shunts, we have FixedAdmittance and SwitchedAdmittance types.
        # To avoid potential name collision, we add the connected bus number to the name.
        name = join(strip.(string.((device_dict["shunt_bus"], device_dict["name"]))), "-")
    elseif haskey(device_dict, "name")
        name = string(device_dict["name"])
    elseif haskey(device_dict, "source_id")
        name = strip(join(string.(device_dict["source_id"]), "-"))
    else
        name = string(device_dict["index"])
    end
    return name
end

function _get_pm_bus_name(device_dict::Dict, unique_names::Bool)
    if haskey(device_dict, "name")
        if unique_names
            name = strip(device_dict["name"])
        else
            name = strip(device_dict["name"]) * "_" * string(device_dict["bus_i"])
        end
    else
        name = strip(join(string.(device_dict["source_id"]), "-"))
    end
    return name
end

"""
Internal branch name retrieval from pm2ps_dict
"""
function _get_pm_branch_name(device_dict, bus_f::ACBus, bus_t::ACBus)
    # Additional if-else are used to catch line id in PSSe parsing cases
    if haskey(device_dict, "name")
        index = device_dict["name"]
    elseif device_dict["source_id"][1] == "branch" && length(device_dict["source_id"]) > 2
        index = strip(device_dict["source_id"][4])
    elseif (
        device_dict["source_id"][1] == "switch" || device_dict["source_id"][1] == "breaker"
    ) && length(device_dict["source_id"]) > 2
        index = string(device_dict["source_id"][4][2])
    elseif device_dict["source_id"][1] == "transformer" &&
           length(device_dict["source_id"]) > 3
        index = strip(device_dict["source_id"][5])
    else
        index = device_dict["index"]
    end
    return "$(get_name(bus_f))-$(get_name(bus_t))-i_$index"
end

"""
Internal 3WT name retrieval from pm2ps_dict
"""
function _get_pm_3w_name(
    device_dict,
    bus_primary::ACBus,
    bus_secondary::ACBus,
    bus_tertiary::ACBus,
)
    ckt = device_dict["circuit"]
    return "$(get_name(bus_primary))-$(get_name(bus_secondary))-$(get_name(bus_tertiary))-i_$ckt"
end

"""Add geographic coordinates to all buses using pre-built lookup"""
function add_geographic_info_to_buses!(sys, substation_data)
    if isempty(substation_data)
        @warn "No substation data found"
        return
    end

    bus_coords_lookup = Dict{Int, GeographicInfo}()

    for (_, substation) in substation_data
        if haskey(substation, "nodes") && haskey(substation, "latitude") &&
           haskey(substation, "longitude")
            lat, lon = substation["latitude"], substation["longitude"]

            geo_info = GeographicInfo(;
                geo_json = Dict(
                    "type" => "Point",
                    "coordinates" => [lon, lat],
                ),
            )
            for node in substation["nodes"]
                if haskey(node, "I")
                    bus_coords_lookup[node["I"]] = geo_info
                end
            end
        end
    end

    begin_supplemental_attributes_update(sys) do
        buses_with_coords = 0
        buses_without_coords = 0

        for bus in get_components(ACBus, sys)
            bus_number = get_number(bus)

            if haskey(bus_coords_lookup, bus_number)
                geo_info = bus_coords_lookup[bus_number]
                add_supplemental_attribute!(sys, bus, geo_info)
                buses_with_coords += 1
            else
                buses_without_coords += 1
            end
        end

        @info "Added coordinates to $(buses_with_coords) buses, $(buses_without_coords) buses without coordinates"
    end
end

"""
Parses ITC data from a dictionary and constructs a lookup table
of piecewise linear scaling functions.
"""
function _impedance_correction_table_lookup(data::Dict)
    ict_instances = Dict{Tuple{Int64, WindingCategory}, ImpedanceCorrectionData}()

    @info "Reading Impedance Correction Table data"
    if !haskey(data, "impedance_correction")
        @info "There is no Impedance Correction Table data in this file"
        return ict_instances
    end

    for (_, table_data) in data["impedance_correction"]
        table_number = table_data["table_number"]
        x = table_data["tap_or_angle"]
        y = table_data["scaling_factor"]

        if length(x) == length(y)
            if length(x) < 2
                @warn "Skipping impedance correction entry due to insufficient data points ($(length(x)) < 2): $(x)"
                continue
            end
            pwl_data = PiecewiseLinearData([(x[i], y[i]) for i in eachindex(x)])
            table_type =
                if (
                    x[1] >= PSSE_PARSER_TAP_RATIO_LBOUND &&
                    x[1] <= PSSE_PARSER_TAP_RATIO_UBOUND
                )
                    ImpedanceCorrectionTransformerControlMode.TAP_RATIO
                else
                    ImpedanceCorrectionTransformerControlMode.PHASE_SHIFT_ANGLE
                end

            for winding_index in instances(WindingCategory)
                ict_instances[(table_number, winding_index)] = ImpedanceCorrectionData(;
                    table_number = table_number,
                    impedance_correction_curve = pwl_data,
                    transformer_winding = winding_index,
                    transformer_control_mode = table_type,
                )
            end
        else
            throw(
                DataFormatError(
                    "Impedance correction mismatch at table $table_number: tap/angle and scaling count differs.",
                ),
            )
        end
    end

    return ict_instances
end

"""
Function to attach ICTs to a single Transformer component.
"""
function _attach_single_ict!(
    sys::System,
    transformer::Union{TwoWindingTransformer, ThreeWindingTransformer},
    name::String,
    d::Dict,
    table_key::String,
    winding_idx::WindingCategory,
    ict_instances::Dict{Tuple{Int64, WindingCategory}, ImpedanceCorrectionData},
)
    if isempty(ict_instances)
        return
    end
    if haskey(d, table_key)
        table_number = d[table_key]
        cache_key = (table_number, winding_idx)
        if haskey(ict_instances, cache_key)
            ict = ict_instances[cache_key]
            add_supplemental_attribute!(sys, transformer, ict)
        else
            @debug "No correction table associated with transformer $name for winding $winding_idx."
        end
    end
    return
end

"""
Attaches the corresponding ICT data to a TwoWindingTransformer component.
"""
function _attach_impedance_correction_tables!(
    sys::System,
    transformer::TwoWindingTransformer,
    name::String,
    d::Dict,
    ict_instances::Dict{Tuple{Int64, WindingCategory}, ImpedanceCorrectionData},
)
    _attach_single_ict!(
        sys,
        transformer,
        name,
        d,
        "correction_table",
        WindingCategory.TR2W_WINDING,
        ict_instances,
    )
    return
end

"""
Attaches the corresponding ICT data to a ThreeWindingTransformer component.
"""
function _attach_impedance_correction_tables!(
    sys::System,
    transformer::ThreeWindingTransformer,
    name::String,
    d::Dict,
    ict_instances::Dict{Tuple{Int64, WindingCategory}, ImpedanceCorrectionData},
)
    if isempty(ict_instances)
        return
    end
    for winding_category in instances(WindingCategory)
        winding_category == WindingCategory.TR2W_WINDING && continue
        key = "$(WINDING_NAMES[winding_category])_correction_table"
        _attach_single_ict!(sys, transformer, name, d, key, winding_category, ict_instances)
    end
    return
end

"""
Creates a PowerSystems.ACBus from a PowerSystems bus dictionary
"""
function make_bus(bus_dict::Dict{String, Any})
    bus = ACBus(
        bus_dict["number"],
        bus_dict["name"],
        bus_dict["available"],
        bus_dict["bustype"],
        bus_dict["angle"],
        bus_dict["voltage"],
        bus_dict["voltage_limits"],
        bus_dict["base_voltage"],
        bus_dict["area"],
        bus_dict["zone"],
    )
    return bus
end

function make_bus(
    bus_name::Union{String, SubString{String}},
    bus_number::Int,
    d,
    bus_types,
    area::Area,
)
    bus = make_bus(
        Dict{String, Any}(
            "name" => bus_name,
            "number" => bus_number,
            "available" => d["bus_status"],
            "bustype" => bus_types[d["bus_type"]],
            "angle" => d["va"],
            "voltage" => d["vm"],
            "voltage_limits" => (min = d["vmin"], max = d["vmax"]),
            "base_voltage" => d["base_kv"],
            "area" => area,
            "zone" => nothing,
        ),
    )
    return bus
end

# Disabling this because not all matpower files define areas even when bus definitions
# contain area references.
#function read_area!(sys::System, data::Dict; kwargs...)
#    if !haskey(data, "areas")
#        @info "There are no Areas in this file"
#        return
#    end
#
#    for (key, val) in data["areas"]
#        area = Area(string(val["col_1"]))
#        add_component!(sys, area; skip_validation = SKIP_PM_VALIDATION)
#    end
#end

function read_bus!(sys::System, data::Dict; kwargs...)
    @info "Reading bus data"

    bus_number_to_bus = Dict{Int, ACBus}()

    bus_types = instances(ACBusTypes)
    unique_bus_names = true
    bus_data = SortedDict{Int, Any}()
    # Bus name uniqueness is not enforced by PSSE. This loop avoids forcing the users to have to
    # pass the bus formatter always for larger datasets.
    bus_names = Set{String}()
    for (k, b) in data["bus"]
        # If buses aren't unique stop searching and growing the set
        if unique_bus_names && haskey(b, "name")
            if b["name"] ∈ bus_names
                unique_bus_names = false
            end
            push!(bus_names, b["name"])
        end
        bus_data[k] = b
    end
    if isempty(bus_data)
        @error "No bus data found" # TODO : need for a model without a bus
    end

    default_bus_naming = x -> _get_pm_bus_name(x, unique_bus_names)

    _get_name = get(kwargs, :bus_name_formatter, default_bus_naming)

    default_area_naming = string
    # The formatter for area_name should be a function that transform the Area Int to a String
    _get_name_area = get(kwargs, :area_name_formatter, default_area_naming)

    for (i, (d_key, d)) in enumerate(bus_data)
        # d id the data dict for each bus
        # d_key is bus key
        bus_name = strip(_get_name(d))
        bus_number = Int(d["bus_i"])

        area_name = _get_name_area(d["area"])
        area = get_component(Area, sys, area_name)
        if isnothing(area)
            area = Area(area_name)
            add_component!(sys, area; skip_validation = SKIP_PM_VALIDATION)
        end

        # Store area data into ext dictionary
        ext = Dict{String, Any}(
            "ARNAME" => "",
            "I" => "",
            "ISW" => "",
            "PDES" => "",
            "PTOL" => "",
        )
        if data["source_type"] == "pti" && haskey(data, "area_interchange")
            for (_, area_data) in data["area_interchange"]
                if haskey(area_data, "area_number") &&
                   string(area_data["area_number"]) == area_name
                    ext["ARNAME"] = strip(get(area_data, "area_name", ""))
                    ext["I"] = string(get(area_data, "area_number", ""))
                    ext["ISW"] = string(get(area_data, "bus_number", ""))
                    ext["PDES"] = get(area_data, "net_interchange", "")
                    ext["PTOL"] = get(area_data, "tol_interchange", "")
                    break  # Only one match is allowed
                end
            end
        end
        set_ext!(area, ext)
        if !haskey(d, "bus_status")
            d["bus_status"] = true
        end
        bus = make_bus(bus_name, bus_number, d, bus_types, area)
        has_component(ACBus, sys, bus_name) && throw(
            DataFormatError(
                "Found duplicate bus names for $(get_name(bus)), consider reviewing your `bus_name_formatter` function",
            ),
        )

        bus_number_to_bus[bus.number] = bus
        add_component!(sys, bus; skip_validation = SKIP_PM_VALIDATION)
    end

    if data["source_type"] == "pti" && haskey(data, "interarea_transfer")
        # get Inter-area Transfers as AreaInterchange
        for (k, d) in data["interarea_transfer"]
            area_from_name = _get_name_area(d["area_from"])
            area_to_name = _get_name_area(d["area_to"])
            transfer_id = get(d, "transfer_id", "1") # 1 by default

            from_area = get_component(Area, sys, area_from_name)
            to_area = get_component(Area, sys, area_to_name)

            name = "$(area_from_name)_$(area_to_name)_$(transfer_id)"

            if isnothing(from_area) || isnothing(to_area)
                missing_areas = join(
                    filter(
                        !isnothing,
                        [
                            isnothing(from_area) ? area_from_name : nothing,
                            isnothing(to_area) ? area_to_name : nothing,
                        ],
                    ),
                    ", ",
                )
                @warn "Inter-area transfer record $k references undefined area(s) $missing_areas; skipping AreaInterchange $name"
                continue
            end

            available = true
            active_power_flow = d["power_transfer"]
            flow_limits = (from_to = -INFINITE_BOUND, to_from = INFINITE_BOUND)

            ext = Dict{String, Any}(
                "index" => d["index"],
                "source_id" => ["interarea_transfer", k],
            )

            interarea_inter = AreaInterchange(;
                name = name,
                available = available,
                active_power_flow = active_power_flow,
                from_area = from_area,
                to_area = to_area,
                flow_limits = flow_limits,
                ext = ext,
            )

            add_component!(sys, interarea_inter; skip_validation = SKIP_PM_VALIDATION)
        end
    end

    return bus_number_to_bus
end

function make_interruptible_powerload(d::Dict, bus::ACBus, sys_mbase::Float64; kwargs...)
    operation_cost = LoadCost(;
        variable = zero(CostCurve),
        fixed = 0.0,
    )

    _get_name = get(kwargs, :load_name_formatter, x -> strip(join(x["source_id"])))
    return InterruptiblePowerLoad(;
        name = _get_name(d),
        available = d["status"],
        bus = bus,
        active_power = d["pd"],
        reactive_power = d["qd"],
        max_active_power = d["pd"],
        max_reactive_power = d["qd"],
        base_power = sys_mbase,
        operation_cost = operation_cost,
        ext = get(d, "ext", Dict{String, Any}()),
    )
end

function make_interruptible_standardload(d::Dict, bus::ACBus, sys_mbase::Float64; kwargs...)
    operation_cost = LoadCost(;
        variable = zero(CostCurve),
        fixed = 0.0,
    )

    _get_name = get(kwargs, :load_name_formatter, x -> strip(join(x["source_id"])))
    return InterruptibleStandardLoad(;
        name = _get_name(d),
        available = d["status"],
        bus = bus,
        base_power = sys_mbase,
        conformity = d["conformity"],
        operation_cost = operation_cost,
        constant_active_power = d["pd"],
        constant_reactive_power = d["qd"],
        current_active_power = d["pi"],
        current_reactive_power = d["qi"],
        impedance_active_power = d["py"],
        impedance_reactive_power = d["qy"],
        max_constant_active_power = d["pd"],
        max_constant_reactive_power = d["qd"],
        max_current_active_power = d["pi"],
        max_current_reactive_power = d["qi"],
        max_impedance_active_power = d["py"],
        max_impedance_reactive_power = d["qy"],
        ext = get(d, "ext", Dict{String, Any}()),
    )
end

function make_power_load(d::Dict, bus::ACBus, sys_mbase::Float64; kwargs...)
    _get_name = get(kwargs, :load_name_formatter, x -> strip(join(x["source_id"])))
    return PowerLoad(;
        name = _get_name(d),
        available = d["status"],
        bus = bus,
        active_power = d["pd"],
        reactive_power = d["qd"],
        max_active_power = d["pd"],
        max_reactive_power = d["qd"],
        base_power = sys_mbase,
        conformity = d["conformity"],
        ext = get(d, "ext", Dict{String, Any}()),
    )
end

function make_standard_load(d::Dict, bus::ACBus, sys_mbase::Float64; kwargs...)
    _get_name = get(kwargs, :load_name_formatter, x -> strip(join(x["source_id"])))
    return StandardLoad(;
        name = _get_name(d),
        available = d["status"],
        bus = bus,
        constant_active_power = d["pd"],
        constant_reactive_power = d["qd"],
        current_active_power = d["pi"],
        current_reactive_power = d["qi"],
        impedance_active_power = d["py"],
        impedance_reactive_power = d["qy"],
        max_constant_active_power = d["pd"],
        max_constant_reactive_power = d["qd"],
        max_current_active_power = d["pi"],
        max_current_reactive_power = d["qi"],
        max_impedance_active_power = d["py"],
        max_impedance_reactive_power = d["qy"],
        base_power = sys_mbase,
        conformity = d["conformity"],
        ext = get(d, "ext", Dict{String, Any}()),
    )
end

function read_loads!(sys::System, data, bus_number_to_bus::Dict{Int, ACBus}; kwargs...)
    @info "Reading Load data in PowerModels dict to populate System ..."

    if !haskey(data, "load")
        @error "There are no loads in this file"
        return
    end

    sys_mbase = data["baseMVA"]
    for d_key in keys(data["load"])
        d = data["load"][d_key]
        bus = bus_number_to_bus[d["load_bus"]]
        is_interruptible = haskey(d, "interruptible")
        if data["source_type"] == "pti" && is_interruptible && d["interruptible"] != 1
            load = make_standard_load(d, bus, sys_mbase; kwargs...)
            has_component(StandardLoad, sys, get_name(load)) && throw(
                DataFormatError(
                    "Found duplicate load names of $(summary(load)), consider formatting names with `load_name_formatter` kwarg",
                ),
            )
        elseif data["source_type"] == "pti" && is_interruptible && d["interruptible"] == 1
            load = make_interruptible_standardload(d, bus, sys_mbase; kwargs...)
            has_component(InterruptibleStandardLoad, sys, get_name(load)) && throw(
                DataFormatError(
                    "Found duplicate interruptible load names of $(summary(load)), consider formatting names with `load_name_formatter` kwarg",
                ),
            )
        else
            load = make_power_load(d, bus, sys_mbase; kwargs...)
            has_component(PowerLoad, sys, get_name(load)) && throw(
                DataFormatError(
                    "Found duplicate load names of $(summary(load)), consider formatting names with `load_name_formatter` kwarg",
                ),
            )
        end
        add_component!(sys, load; skip_validation = SKIP_PM_VALIDATION)
    end
end

function make_loadzone(
    name::String,
    active_power::Float64,
    reactive_power::Float64;
    kwargs...,
)
    return LoadZone(;
        name = name,
        peak_active_power = active_power,
        peak_reactive_power = reactive_power,
    )
end

function read_loadzones!(
    sys::System,
    data::Dict{String, Any},
    bus_number_to_bus::Dict{Int, ACBus};
    kwargs...,
)
    @info "Reading LoadZones data in PowerModels dict to populate System ..."
    zones = Set{Int}()
    zone_bus_map = Dict{Int, Vector}()
    for (_, bus) in data["bus"]
        push!(zones, bus["zone"])
        push!(get!(zone_bus_map, bus["zone"], Vector()), bus)
    end

    load_zone_map =
        Dict{Int, Dict{String, Float64}}(i => Dict("pd" => 0.0, "qd" => 0.0) for i in zones)
    for (key, load) in data["load"]
        zone = data["bus"][load["load_bus"]]["zone"]
        load_zone_map[zone]["pd"] += load["pd"]
        load_zone_map[zone]["qd"] += load["qd"]
        # Use get with defaults because matpower data doesn't have other load representations
        load_zone_map[zone]["pd"] += get(load, "pi", 0.0)
        load_zone_map[zone]["qd"] += get(load, "qi", 0.0)
        load_zone_map[zone]["pd"] += get(load, "py", 0.0)
        load_zone_map[zone]["qd"] += get(load, "qy", 0.0)
    end

    default_loadzone_naming = string
    # The formatter for loadzone_name should be a function that transform the LoadZone Int to a String
    _get_name = get(kwargs, :loadzone_name_formatter, default_loadzone_naming)

    @info "Reading Zone data"
    if !haskey(data, "zone")
        @info "There is no Zone data in this file"
    else
        for (_, v) in data["zone"]
            zone_number = v["zone_number"]
            if !(zone_number in zones)
                @warn "Skipping empty LoadZone $(zone_number)-$(v["zone_name"])"
            end
        end
    end

    for zone in zones
        name = _get_name(zone)
        load_zone = make_loadzone(
            name,
            load_zone_map[zone]["pd"],
            load_zone_map[zone]["qd"];
            kwargs...,
        )
        add_component!(sys, load_zone; skip_validation = SKIP_PM_VALIDATION)
        for bus in zone_bus_map[zone]
            set_load_zone!(bus_number_to_bus[bus["bus_i"]], load_zone)
        end
    end
end

function make_hydro_dispatch(
    gen_name::Union{SubString{String}, String},
    d::Dict,
    bus::ACBus,
    sys_mbase::Float64,
)
    curtailcost = HydroGenerationCost(zero(CostCurve), 0.0)

    if d["mbase"] != 0.0
        mbase = d["mbase"]
    else
        @warn "Generator $gen_name has base power equal to zero: $(d["mbase"]). Changing it to system base: $sys_mbase" _group =
            IS.LOG_GROUP_PARSING
        mbase = sys_mbase
    end

    base_conversion = sys_mbase / mbase
    return HydroDispatch(; # No way to define storage parameters for gens in PM so can only make HydroDispatch
        name = gen_name,
        available = Bool(d["gen_status"]),
        bus = bus,
        active_power = d["pg"] * base_conversion,
        reactive_power = d["qg"] * base_conversion,
        rating = calculate_gen_rating(d["pmax"], d["qmax"], base_conversion),
        prime_mover_type = parse_enum_mapping(PrimeMovers, d["type"]),
        active_power_limits = (
            min = d["pmin"] * base_conversion,
            max = d["pmax"] * base_conversion,
        ),
        reactive_power_limits = (
            min = d["qmin"] * base_conversion,
            max = d["qmax"] * base_conversion,
        ),
        ramp_limits = calculate_ramp_limit(d, gen_name),
        time_limits = nothing,
        operation_cost = curtailcost,
        base_power = mbase,
    )
end

function make_hydro_reservoir(
    gen_name::Union{SubString{String}, String},
    d::Dict,
    bus::ACBus,
    sys_mbase::Float64,
)
    curtailcost = HydroGenerationCost(zero(CostCurve), 0.0)

    if d["mbase"] != 0.0
        mbase = d["mbase"]
    else
        @warn "Generator $gen_name has base power equal to zero: $(d["mbase"]). Changing it to system base: $sys_mbase" _group =
            IS.LOG_GROUP_PARSING
        mbase = sys_mbase
    end

    base_conversion = sys_mbase / mbase
    return HydroDispatch(; # No way to define storage parameters for gens in PM so can only make HydroDispatch
        name = gen_name,
        available = Bool(d["gen_status"]),
        bus = bus,
        active_power = d["pg"] * base_conversion,
        reactive_power = d["qg"] * base_conversion,
        rating = calculate_gen_rating(d["pmax"], d["qmax"], base_conversion),
        prime_mover_type = parse_enum_mapping(PrimeMovers, d["type"]),
        active_power_limits = (
            min = d["pmin"] * base_conversion,
            max = d["pmax"] * base_conversion,
        ),
        reactive_power_limits = (
            min = d["qmin"] * base_conversion,
            max = d["qmax"] * base_conversion,
        ),
        ramp_limits = calculate_ramp_limit(d, gen_name),
        time_limits = nothing,
        operation_cost = curtailcost,
        base_power = mbase,
    )
end

function make_renewable_dispatch(
    gen_name::Union{SubString{String}, String},
    d::Dict,
    bus::ACBus,
    sys_mbase::Float64,
)
    cost = RenewableGenerationCost(zero(CostCurve))

    if d["mbase"] != 0.0
        mbase = d["mbase"]
    else
        @warn "Generator $gen_name has base power equal to zero: $(d["mbase"]). Changing it to system base: $sys_mbase" _group =
            IS.LOG_GROUP_PARSING
        mbase = sys_mbase
    end

    base_conversion = sys_mbase / mbase

    rating = calculate_gen_rating(d["pmax"], d["qmax"], base_conversion)
    if rating > mbase
        @warn "rating is larger than base power for $gen_name, setting to $mbase" _group =
            IS.LOG_GROUP_PARSING
        rating = mbase
    end

    generator = RenewableDispatch(;
        name = gen_name,
        available = Bool(d["gen_status"]),
        bus = bus,
        active_power = d["pg"] * base_conversion,
        reactive_power = d["qg"] * base_conversion,
        rating = rating * base_conversion,
        prime_mover_type = parse_enum_mapping(PrimeMovers, d["type"]),
        reactive_power_limits = (
            min = d["qmin"] * base_conversion,
            max = d["qmax"] * base_conversion,
        ),
        power_factor = 1.0,
        operation_cost = cost,
        base_power = mbase,
    )

    return generator
end

function make_renewable_fix(
    gen_name::Union{SubString{String}, String},
    d::Dict,
    bus::ACBus,
    sys_mbase::Float64,
)
    if d["mbase"] != 0.0
        mbase = d["mbase"]
    else
        @warn "Generator $gen_name has base power equal to zero: $(d["mbase"]). Changing it to system base: $sys_mbase" _group =
            IS.LOG_GROUP_PARSING
        mbase = sys_mbase
    end

    base_conversion = sys_mbase / mbase
    generator = RenewableNonDispatch(;
        name = gen_name,
        available = Bool(d["gen_status"]),
        bus = bus,
        active_power = d["pg"] * base_conversion,
        reactive_power = d["qg"] * base_conversion,
        rating = float(d["pmax"]) * base_conversion,
        prime_mover_type = parse_enum_mapping(PrimeMovers, d["type"]),
        power_factor = 1.0,
        base_power = mbase,
    )

    return generator
end

function make_generic_battery(
    storage_name::Union{SubString{String}, String},
    d::Dict,
    bus::ACBus,
)
    energy_rating = iszero(d["energy_rating"]) ? d["energy"] : d["energy_rating"]
    storage = EnergyReservoirStorage(;
        name = storage_name,
        available = Bool(d["status"]),
        bus = bus,
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        storage_capacity = energy_rating,
        storage_level_limits = (min = 0.0, max = energy_rating),
        initial_storage_capacity_level = d["energy"] / energy_rating,
        rating = d["thermal_rating"],
        active_power = d["ps"],
        input_active_power_limits = (min = 0.0, max = d["charge_rating"]),
        output_active_power_limits = (min = 0.0, max = d["discharge_rating"]),
        efficiency = (in = d["charge_efficiency"], out = d["discharge_efficiency"]),
        reactive_power = d["qs"],
        reactive_power_limits = (min = d["qmin"], max = d["qmax"]),
        base_power = d["thermal_rating"],
    )
    return storage
end

function _is_likely_motor_load(d::Dict, gen_name::Union{SubString{String}, String})
    # A motor load is likely if it has a negative active power and a non-zero reactive power.
    # This is a heuristic and may not be accurate for all cases.
    # likely_motor_load
    if d["pmin"] < 0 && d["pmax"] < 0 && d["pg"] < 0
        @warn "Generator $gen_name is likely a motor load with negative active power: $(d["pg"]) and negative power limits: (min = $(d["pmin"]), max = $(d["pmax"])) \
        this component will be parsed as a thermal generator with negative active power limits. You can convert the device to a MotorLoad for more accurate modeling."
    end

    if d["pmin"] == 0 && d["pmax"] == 0 && d["pg"] < 0
        @warn "Generator $gen_name is likely a motor load with negative active power: $(d["pg"]) and undefined active power limits \
        this component will be parsed as a thermal generator with negative active power injection. You can convert the device to a MotorLoad for more accurate modeling."
    end

    if d["pmin"] < 0 && d["pmax"] == 0
        @warn "Generator $gen_name is likely something that is not a ThermalGenerators with negative power limits: (min = $(d["pmin"]), max = $(d["pmax"])) \
        this component will be parsed as a thermal generator with negative active power limits. Check this entry for more accurate modeling."
    end
    return
end

# TODO test this more directly?
"""
The polynomial term follows the convention that for an n-degree polynomial, at least n + 1 components are needed.
    c(p) = c_n*p^n+...+c_1p+c_0
    c_o is stored in the  field in of the Econ Struct
"""
function make_thermal_gen(
    gen_name::Union{SubString{String}, String},
    d::Dict,
    bus::ACBus,
    sys_mbase::Float64,
)
    if haskey(d, "model")
        model = PSY.GeneratorCostModels(d["model"])
        # Input data layout: table B-4 of https://matpower.org/docs/MATPOWER-manual.pdf
        if model == PSY.GeneratorCostModels.PIECEWISE_LINEAR
            # For now, we make the fixed cost the y-intercept of the first segment of the
            # piecewise curve and the variable cost a PiecewiseLinearData representing
            # the data minus this fixed cost; in a future update, there will be no
            # separation between the PiecewiseLinearData and the fixed cost.
            cost_component = d["cost"]
            power_p = [i for (ix, i) in enumerate(cost_component) if isodd(ix)]
            cost_p = [i for (ix, i) in enumerate(cost_component) if iseven(ix)]
            points = collect(zip(power_p, cost_p))
            (first_x, first_y) = first(points)
            fixed = max(0.0,
                first_y - first(get_slopes(PiecewiseLinearData(points))) * first_x,
            )
            cost = PiecewiseLinearData([(x, y - fixed) for (x, y) in points])
        elseif model == PSY.GeneratorCostModels.POLYNOMIAL
            # For now, we make the variable cost a QuadraticFunctionData with all but the
            # constant term and make the fixed cost the constant term; in a future update,
            # there will be no separation between the QuadraticFunctionData and the fixed
            # cost.
            # This transforms [3.0, 1.0, 4.0, 2.0] into [(1, 4.0), (2, 1.0), (3, 3.0)]
            coeffs = enumerate(reverse(d["cost"][1:(end - 1)]))
            coeffs = Dict((i, c / sys_mbase^i) for (i, c) in coeffs)
            quadratic_degrees = [2, 1, 0]
            (keys(coeffs) <= Set(quadratic_degrees)) || throw(
                ArgumentError(
                    "Can only handle polynomials up to degree two; given coefficients $coeffs",
                ),
            )
            cost = QuadraticFunctionData(get.(Ref(coeffs), quadratic_degrees, 0)...)
            fixed = (d["ncost"] >= 1) ? last(d["cost"]) : 0.0
        end
        cost = CostCurve(InputOutputCurve((cost)), IS.DU)
        startup = d["startup"]
        shutdn = d["shutdown"]
    else
        @warn "Generator cost data not included for Generator: $gen_name"
        tmpcost = ThermalGenerationCost(nothing)
        cost = tmpcost.variable
        fixed = tmpcost.fixed
        startup = tmpcost.start_up
        shutdn = tmpcost.shut_down
    end

    operation_cost = ThermalGenerationCost(;
        variable = cost,
        fixed = fixed,
        start_up = startup,
        shut_down = shutdn,
    )

    if !haskey(d, "ext")
        d["ext"] = Dict{String, Float64}()
    end

    if haskey(d, "r_source") && haskey(d, "x_source")
        d["ext"]["r"] = d["r_source"]
        d["ext"]["x"] = d["x_source"]
    end

    if haskey(d, "rt_source") && haskey(d, "xt_source")
        d["ext"]["rt"] = d["rt_source"]
        d["ext"]["xt"] = d["xt_source"]
    end

    if d["mbase"] != 0.0
        mbase = d["mbase"]
    else
        @warn "Generator $gen_name has base power equal to zero: $(d["mbase"]). Changing it to system base: $sys_mbase" _group =
            IS.LOG_GROUP_PARSING
        mbase = sys_mbase
    end

    base_conversion = sys_mbase / mbase
    _is_likely_motor_load(d, gen_name)
    thermal_gen = ThermalStandard(;
        name = gen_name,
        status = Bool(d["gen_status"]),
        available = Bool(d["gen_status"]),
        bus = bus,
        active_power = d["pg"] * base_conversion,
        reactive_power = d["qg"] * base_conversion,
        rating = calculate_gen_rating(d["pmax"], d["qmax"], base_conversion),
        prime_mover_type = parse_enum_mapping(PrimeMovers, d["type"]),
        fuel = parse_enum_mapping(ThermalFuels, d["fuel"]),
        active_power_limits = (
            min = d["pmin"] * base_conversion,
            max = d["pmax"] * base_conversion,
        ),
        reactive_power_limits = (
            min = d["qmin"] * base_conversion,
            max = d["qmax"] * base_conversion,
        ),
        ramp_limits = calculate_ramp_limit(d, gen_name),
        time_limits = nothing,
        operation_cost = operation_cost,
        base_power = mbase,
        ext = get(d, "ext", Dict{String, Any}()),
    )

    return thermal_gen
end

function make_synchronous_condenser(
    gen_name::Union{SubString{String}, String},
    d::Dict,
    bus::ACBus,
    sys_mbase::Float64,
)
    ext = get(d, "ext", Dict{String, Any}())
    if haskey(d, "r_source") && haskey(d, "x_source")
        ext["r"] = d["r_source"]
        ext["x"] = d["x_source"]
    end

    if haskey(d, "rt_source") && haskey(d, "xt_source")
        ext["rt"] = d["rt_source"]
        ext["xt"] = d["xt_source"]
    end

    if d["mbase"] != 0.0
        mbase = d["mbase"]
    else
        @warn "Generator $gen_name has base power equal to zero: $(d["mbase"]). Changing it to system base: $sys_mbase" _group =
            IS.LOG_GROUP_PARSING
        mbase = sys_mbase
    end

    # NOTE: qmax and qmin can be both negatives, so this approach is taken for the rating.
    base_conversion = sys_mbase / mbase
    synchronous_condenser = SynchronousCondenser(;
        name = gen_name,
        available = Bool(d["gen_status"]),
        bus = bus,
        reactive_power = d["qg"] * base_conversion,
        rating = max(abs(d["qmax"]), abs(d["qmin"])) * base_conversion,
        reactive_power_limits = (
            min = d["qmin"] * base_conversion,
            max = d["qmax"] * base_conversion,
        ),
        base_power = mbase,
        ext = ext,
    )

    return synchronous_condenser
end

"""
Transfer generators to ps_dict according to their classification
"""
function read_gen!(sys::System, data::Dict, bus_number_to_bus::Dict{Int, ACBus}; kwargs...)
    @info "Reading generator data"

    if !haskey(data, "gen")
        @error "There are no Generators in this file"
        return nothing
    end

    generator_mapping = get(kwargs, :generator_mapping, GENERATOR_MAPPING_FILE_PM)
    try
        generator_mapping = get_generator_mapping(generator_mapping)
    catch e
        @error "Error loading generator mapping $(generator_mapping)"
        rethrow(e)
    end

    sys_mbase = data["baseMVA"]

    _get_name = get(kwargs, :gen_name_formatter, _get_pm_dict_name)
    for (name, pm_gen) in data["gen"]
        gen_name = _get_name(pm_gen)

        bus = bus_number_to_bus[pm_gen["gen_bus"]]
        pm_gen["fuel"] = get(pm_gen, "fuel", "OTHER")
        pm_gen["type"] = get(pm_gen, "type", "OT")
        @debug "Found generator" _group = IS.LOG_GROUP_PARSING gen_name bus pm_gen["fuel"] pm_gen["type"]

        gen_type = get_generator_type(pm_gen["fuel"], pm_gen["type"], generator_mapping)
        if gen_type == ThermalStandard
            generator = make_thermal_gen(gen_name, pm_gen, bus, sys_mbase)
        elseif gen_type == HydroDispatch
            generator = make_hydro_dispatch(gen_name, pm_gen, bus, sys_mbase)
        elseif gen_type == HydroTurbine
            # This method adds a
            generator = make_hydro_reservoir(gen_name, pm_gen, bus, sys_mbase)
        elseif gen_type == RenewableDispatch
            generator = make_renewable_dispatch(gen_name, pm_gen, bus, sys_mbase)
        elseif gen_type == RenewableNonDispatch
            generator = make_renewable_fix(gen_name, pm_gen, bus, sys_mbase)
        elseif gen_type == SynchronousCondenser
            generator = make_synchronous_condenser(gen_name, pm_gen, bus, sys_mbase)
        elseif gen_type == EnergyReservoirStorage
            @warn "EnergyReservoirStorage should be defined as a PowerModels storage... Skipping"
            continue
        else
            @error "Skipping unsupported generator" gen_type
            continue
        end

        has_component(typeof(generator), sys, get_name(generator)) && throw(
            DataFormatError(
                "Found duplicate $(typeof(generator)) names of $(get_name(generator)), consider formatting names with `gen_name_formatter` kwarg",
            ),
        )
        add_component!(sys, generator; skip_validation = SKIP_PM_VALIDATION)
    end
end

const _SHIFT_TO_GROUP_MAP = Dict{Float64, WindingGroupNumber}(
    0.0 => WindingGroupNumber.GROUP_0,
    -30.0 => WindingGroupNumber.GROUP_1,
    -150.0 => WindingGroupNumber.GROUP_5,
    180.0 => WindingGroupNumber.GROUP_6,
    150.0 => WindingGroupNumber.GROUP_7,
    30.0 => WindingGroupNumber.GROUP_11,
)

"""
Resolve the [`WindingGroupNumber`](@ref) from the phase-shift angle stored under
`angle_key` (radians). Stores the result in `d[group_key]` (dict consumers read it
there) and returns it so the caller can use it directly.
"""
function _add_vector_control_group(d::Dict, angle_key::String, group_key::String)
    angle = d[angle_key]
    group = WindingGroupNumber.UNDEFINED
    for (angle_key_deg, candidate) in _SHIFT_TO_GROUP_MAP
        if isapprox(rad2deg(angle), angle_key_deg)
            group = candidate
            break
        end
    end
    d[group_key] = group
    return group
end

# Tap changing and phase shifting are winding data (`tap`, `α`, `control`), not
# distinct component types, so these type-inference helpers only distinguish
# Line / switch / transformer.
function get_branch_type_matpower(
    d::Dict,
)
    tap = d["tap"]
    shift = d["shift"]
    is_transformer = d["transformer"]
    if !is_transformer
        is_transformer = (tap != 0.0) && (tap != 1.0) || (shift != 0.0)
    end

    is_transformer || return Line
    return TwoWindingTransformer
end

function get_branch_type_psse(
    d::Dict,
)
    if d["br_r"] == 0.0 && d["br_x"] == 0.0
        return DiscreteControlledACBranch
    end

    is_transformer = d["transformer"]
    tap = d["tap"]

    if !is_transformer
        if (tap != 0.0) && (tap != 1.0)
            @warn "Transformer $d has tap ratio $tap, which is not 0.0 or 1.0; this is not a valid value for a Line. Parsing entry as a Transformer"
        else
            return Line
        end
    end

    return TwoWindingTransformer
end

function make_branch(
    name::String,
    d::Dict,
    bus_f::ACBus,
    bus_t::ACBus,
    source_type::String,
)
    if source_type == "matpower"
        branch_type = get_branch_type_matpower(d)
    elseif source_type == "pti"
        branch_type = get_branch_type_psse(d)
    else
        error("Source Type $source_type not supported")
    end

    if d["transformer"] && branch_type == Line
        throw(
            DataFormatError(
                "Branch data mismatched, cannot build the branch correctly for $d",
            ),
        )
    elseif branch_type == DiscreteControlledACBranch
        value = _make_switch_from_zero_impedance_line(name, d, bus_f, bus_t)
    elseif branch_type == TwoWindingTransformer
        value = make_transformer_2w(name, d, bus_f, bus_t)
    elseif branch_type == Line
        value = make_line(name, d, bus_f, bus_t)
    else
        error("Unsupported branch type $branch_type")
    end
    return value
end

function _make_switch_from_zero_impedance_line(
    name::String,
    d::Dict,
    bus_f::ACBus,
    bus_t::ACBus,
)
    pf = get(d, "pf", 0.0)
    qf = get(d, "qf", 0.0)
    available_value = d["br_status"] == 1
    if get_bustype(bus_f) == ACBusTypes.ISOLATED ||
       get_bustype(bus_t) == ACBusTypes.ISOLATED
        available_value = false
    end
    if available_value == true
        status_value = DiscreteControlledBranchStatus.CLOSED
    else
        status_value = DiscreteControlledBranchStatus.OPEN
    end
    @warn "Branch $name has zero impedance and available = $available_value; converting to a DiscreteControlledACBranch of type SWITCH with available = $available_value and branch_status = $status_value"
    return DiscreteControlledACBranch(;
        name = name,
        available = Bool(available_value),
        active_power_flow = pf,
        reactive_power_flow = qf,
        arc = Arc(bus_f, bus_t),
        r = d["br_r"],
        x = d["br_x"],
        rating = _get_rating("Line", name, d, "rate_a"),
        discrete_branch_type = DiscreteControlledBranchType.SWITCH,
        branch_status = status_value,
    )
end

function _get_rating(
    branch_type::String,
    name::AbstractString,
    line_data::Dict,
    key::String,
)
    haskey(line_data, key) || return key == "rate_a" ? INFINITE_BOUND : nothing

    if isapprox(line_data[key], 0.0)
        @info(
            "$branch_type $name rating value: $(line_data[key]). Unbounded value implied as per PSSe Manual"
        )
        return INFINITE_BOUND
    else
        return line_data[key]
    end
end

function make_line(name::String, d::Dict, bus_f::ACBus, bus_t::ACBus)
    pf = get(d, "pf", 0.0)
    qf = get(d, "qf", 0.0)
    available_value = d["br_status"] == 1
    if get_bustype(bus_f) == ACBusTypes.ISOLATED ||
       get_bustype(bus_t) == ACBusTypes.ISOLATED
        available_value = false
    end

    ext = haskey(d, "ext") ? d["ext"] : Dict{String, Any}()

    return Line(;
        name = name,
        available = available_value,
        active_power_flow = pf,
        reactive_power_flow = qf,
        arc = Arc(bus_f, bus_t),
        r = d["br_r"],
        x = d["br_x"],
        b = (from = d["b_fr"], to = d["b_to"]),
        rating = _get_rating("Line", name, d, "rate_a"),
        angle_limits = (min = d["angmin"], max = d["angmax"]),
        rating_b = _get_rating("Line", name, d, "rate_b"),
        rating_c = _get_rating("Line", name, d, "rate_c"),
        ext = ext,
    )
end

function make_switch_breaker(name::String, d::Dict, bus_f::ACBus, bus_t::ACBus)
    return DiscreteControlledACBranch(;
        name = name,
        available = Bool(d["state"]),
        active_power_flow = d["active_power_flow"],
        reactive_power_flow = d["reactive_power_flow"],
        arc = Arc(bus_f, bus_t),
        r = d["r"],
        x = d["x"],
        rating = d["rating"],
        discrete_branch_type = d["discrete_branch_type"],
        branch_status = d["state"],
        ext = get(d, "ext", Dict{String, Any}()),
    )
end

function read_switch_breaker!(
    sys::System,
    data::Dict,
    bus_number_to_bus::Dict{Int, ACBus},
    device_type::String;
    kwargs...,
)
    @info "Reading $device_type data"
    if !haskey(data, device_type)
        @info "There is no $device_type data in this file"
        return
    end

    _get_name = get(kwargs, :branch_name_formatter, _get_pm_branch_name)

    for (_, d) in data[device_type]
        bus_f = bus_number_to_bus[d["f_bus"]]
        bus_t = bus_number_to_bus[d["t_bus"]]
        name = _get_name(d, bus_f, bus_t)
        value = make_switch_breaker(name, d, bus_f, bus_t)

        add_component!(sys, value; skip_validation = SKIP_PM_VALIDATION)
    end
end

"""
Resolve the flat per-winding control fields from a PowerModels transformer dict
`d` for winding `suffix` (1/2/3), mirroring the PSS/E per-winding control block
(COD/CONT/RMA/RMI/VMA/VMI/NTP). Returns a NamedTuple of the winding's flattened
control keyword arguments.

`COD == -99` (or a missing `COD` key) yields `control_objective = UNDEFINED`, the
null state (no control block). Any other COD — including `0` (FIXED) and negative
(disabled) codes — is preserved as data. Matpower records carry no COD keys, so
`control_objective` stays `UNDEFINED` there (the `get` defaults handle it).
"""
function _transformer_control_fields(d::Dict, suffix::Int)
    cod = get(d, "COD$suffix", -99)
    # RMI/RMA and VMI/VMA are the lower/upper edges of a band. Some (typically
    # synthetic) PSS/E data has them numerically inverted by rounding
    # (e.g. frankenstein_70.raw has VMA1 = 0.984 < VMI1 = 0.985); warn and
    # normalize the ordering so a valid band is produced rather than tripping
    # the attach-time band-ordering check. The warning surfaces genuinely
    # corrupt bands on actively-controlled windings instead of hiding them.
    record = string(get(d, "name", get(d, "source_id", "unknown")))
    rmi, rma = get(d, "RMI$suffix", 0.9), get(d, "RMA$suffix", 1.1)
    if rmi > rma
        @warn "Transformer record $record winding $suffix has inverted control limits RMI$suffix = $rmi > RMA$suffix = $rma; normalizing to (min = $rma, max = $rmi)."
        rmi, rma = rma, rmi
    end
    vmi, vma = get(d, "VMI$suffix", 0.9), get(d, "VMA$suffix", 1.1)
    if vmi > vma
        @warn "Transformer record $record winding $suffix has inverted controlled-quantity limits VMI$suffix = $vmi > VMA$suffix = $vma; normalizing to (min = $vma, max = $vmi)."
        vmi, vma = vma, vmi
    end
    return (
        control_objective = TransformerControlObjective(cod),
        regulated_bus_number = get(d, "CONT$suffix", 0),
        control_limits = (min = rmi, max = rma),
        controlled_quantity_limits = (min = vmi, max = vma),
        number_of_tap_positions = get(d, "NTP$suffix", 33),
    )
end

"""
Build a [`TransformerCircuit`](@ref) from a PowerModels transformer dict `d`,
mapping the per-winding keys named by the keyword arguments. Shared by the 2W
maker (one circuit) and the 3W maker (three circuits). The vector group number is
derived from the phase-shift angle under `angle_key` (see
[`_add_vector_control_group`](@ref)); ratings are resolved by the caller.
"""
function _make_transformer_circuit(
    d::Dict,
    arc::Arc;
    tap_key::String,
    angle_key::String,
    group_key::String,
    control_suffix::Int,
    available::Bool,
    r,
    x,
    rating,
    rating_b = nothing,
    rating_c = nothing,
    base_power,
    base_voltage_primary,
    base_voltage_secondary,
    active_power_flow,
    reactive_power_flow,
)
    control = _transformer_control_fields(d, control_suffix)
    return TransformerCircuit(;
        arc = arc,
        tap = get(d, tap_key, 1.0),
        α = d[angle_key],
        winding_group_number = _add_vector_control_group(d, angle_key, group_key),
        r = r,
        x = x,
        control_objective = control.control_objective,
        regulated_bus_number = control.regulated_bus_number,
        control_limits = control.control_limits,
        controlled_quantity_limits = control.controlled_quantity_limits,
        number_of_tap_positions = control.number_of_tap_positions,
        available = available,
        rating = rating,
        rating_b = rating_b,
        rating_c = rating_c,
        active_power_flow = active_power_flow,
        reactive_power_flow = reactive_power_flow,
        base_power = base_power,
        base_voltage_primary = base_voltage_primary,
        base_voltage_secondary = base_voltage_secondary,
    )
end

# matpower files frequently leave bus base voltages unspecified (baseKV = 0);
# represent that as `nothing` (unknown) rather than a literal 0, which the
# transformer winding validation (base_voltage must be positive) rejects.
_base_voltage_or_nothing(v) = iszero(v) ? nothing : v

function make_transformer_2w(
    name::String,
    d::Dict,
    bus_f::ACBus,
    bus_t::ACBus,
)
    pf = get(d, "pf", 0.0)
    qf = get(d, "qf", 0.0)
    available_value = d["br_status"] == 1
    if get_bustype(bus_f) == ACBusTypes.ISOLATED ||
       get_bustype(bus_t) == ACBusTypes.ISOLATED
        available_value = false
    end

    # `d["base_power"]` is the winding (device) base, which is the transformer's
    # device base.
    base_power = d["base_power"]

    # BASE CONVENTION: `br_r`/`br_x` reach this maker already expressed in device
    # base on `base_power` (PowerFlowFileParser converts PSSE data to device base
    # in `psse.jl`, and `make_per_unit!` does not touch `br_r`/`br_x`; for
    # matpower `base_power == system base` so device base == system base).
    # The circuit's `r`/`x` store the series impedance in device base on
    # `base_power`, so no rebasing is applied here.
    circuit = _make_transformer_circuit(
        d,
        Arc(bus_f, bus_t);
        tap_key = "tap",
        angle_key = "shift",
        group_key = "group_number",
        control_suffix = 1,
        available = available_value,
        r = d["br_r"],
        x = d["br_x"],
        rating = _get_rating("TwoWindingTransformer", name, d, "rate_a"),
        rating_b = _get_rating("TwoWindingTransformer", name, d, "rate_b"),
        rating_c = _get_rating("TwoWindingTransformer", name, d, "rate_c"),
        base_power = base_power,
        # for psse inputs, this may differ from the buses' base voltages
        base_voltage_primary = _base_voltage_or_nothing(d["base_voltage_from"]),
        base_voltage_secondary = _base_voltage_or_nothing(d["base_voltage_to"]),
        active_power_flow = pf,
        reactive_power_flow = qf,
    )

    return TwoWindingTransformer(;
        name = name,
        circuit = circuit,
        magnetizing_shunt = Complex(d["g_fr"], d["b_fr"]),
        ext = get(d, "ext", Dict{String, Any}()),
    )
end

function make_3w_transformer(
    name::String,
    d::Dict,
    bus_primary::ACBus,
    bus_secondary::ACBus,
    bus_tertiary::ACBus,
    star_bus::ACBus,
)
    pf = get(d, "pf", 0.0)
    qf = get(d, "qf", 0.0)

    # Each winding's device (winding) base power is the pairwise base of the pair
    # whose first index is that winding: primary -> base_power_12,
    # secondary -> base_power_23, tertiary -> base_power_31. The star-leg
    # impedances (r_primary/x_primary, ...) reach this maker already on their
    # respective winding device bases (PowerFlowFileParser performs the
    # delta->star conversion), matching the circuit field semantics, so no
    # rebasing is applied. The magnetizing shunt is transformer-level and lives
    # on the parent (PRIMARY = winding-1 terminal side). The star side has no
    # distinct base voltage, so each circuit's secondary base voltage defaults
    # to its primary.
    primary_circuit = _make_transformer_circuit(
        d,
        Arc(bus_primary, star_bus);
        tap_key = "primary_turns_ratio",
        angle_key = "primary_phase_shift_angle",
        group_key = "primary_group_number",
        control_suffix = 1,
        available = Bool(d["available_primary"]),
        r = d["r_primary"],
        x = d["x_primary"],
        rating = _get_rating("ThreeWindingTransformer", name, d, "rating_primary"),
        base_power = d["base_power_12"],
        base_voltage_primary = d["base_voltage_primary"],
        base_voltage_secondary = d["base_voltage_primary"],
        active_power_flow = pf,
        reactive_power_flow = qf,
    )
    secondary_circuit = _make_transformer_circuit(
        d,
        Arc(bus_secondary, star_bus);
        tap_key = "secondary_turns_ratio",
        angle_key = "secondary_phase_shift_angle",
        group_key = "secondary_group_number",
        control_suffix = 2,
        available = Bool(d["available_secondary"]),
        r = d["r_secondary"],
        x = d["x_secondary"],
        rating = _get_rating("ThreeWindingTransformer", name, d, "rating_secondary"),
        base_power = d["base_power_23"],
        base_voltage_primary = d["base_voltage_secondary"],
        base_voltage_secondary = d["base_voltage_secondary"],
        active_power_flow = pf,
        reactive_power_flow = qf,
    )
    tertiary_circuit = _make_transformer_circuit(
        d,
        Arc(bus_tertiary, star_bus);
        tap_key = "tertiary_turns_ratio",
        angle_key = "tertiary_phase_shift_angle",
        group_key = "tertiary_group_number",
        control_suffix = 3,
        available = Bool(d["available_tertiary"]),
        r = d["r_tertiary"],
        x = d["x_tertiary"],
        rating = _get_rating("ThreeWindingTransformer", name, d, "rating_tertiary"),
        base_power = d["base_power_31"],
        base_voltage_primary = d["base_voltage_tertiary"],
        base_voltage_secondary = d["base_voltage_tertiary"],
        active_power_flow = pf,
        reactive_power_flow = qf,
    )

    return ThreeWindingTransformer(;
        name = name,
        primary_circuit = primary_circuit,
        secondary_circuit = secondary_circuit,
        tertiary_circuit = tertiary_circuit,
        magnetizing_shunt = Complex(d["g"], d["b"]),
        star_bus = star_bus,
        r_12 = d["r_12"],
        x_12 = d["x_12"],
        r_23 = d["r_23"],
        x_23 = d["x_23"],
        r_31 = d["r_31"],
        x_31 = d["x_31"],
        base_power_12 = d["base_power_12"],
        base_power_23 = d["base_power_23"],
        base_power_31 = d["base_power_31"],
        ext = get(d, "ext", Dict{String, Any}()),
    )
end

function read_branch!(
    sys::System,
    data::Dict,
    bus_number_to_bus::Dict{Int, ACBus}; kwargs...,
)
    @info "Reading branch data"
    if !haskey(data, "branch")
        @info "There is no Branch data in this file"
        return
    end

    _get_name = get(kwargs, :branch_name_formatter, _get_pm_branch_name)
    ict_instances = _impedance_correction_table_lookup(data)

    source_type = data["source_type"]
    for d in values(data["branch"])
        bus_f = bus_number_to_bus[d["f_bus"]]
        bus_t = bus_number_to_bus[d["t_bus"]]
        name = _get_name(d, bus_f, bus_t)
        value = make_branch(name, d, bus_f, bus_t, source_type)

        if !isnothing(value)
            add_component!(sys, value; skip_validation = SKIP_PM_VALIDATION)
        else
            continue
        end

        if isa(value, TwoWindingTransformer)
            _attach_impedance_correction_tables!(
                sys,
                value,
                name,
                d,
                ict_instances,
            )
        end
    end
    return
end

function read_3w_transformer!(
    sys::System,
    data::Dict,
    bus_number_to_bus::Dict{Int, ACBus};
    kwargs...,
)
    @info "Reading 3W transformer data"
    if !haskey(data, "3w_transformer")
        @info "There is no 3W transformer data in this file"
        return
    end

    _get_name = get(kwargs, :xfrm_3w_name_formatter, _get_pm_3w_name)

    ict_instances = _impedance_correction_table_lookup(data)

    for (_, d) in data["3w_transformer"]
        bus_primary = bus_number_to_bus[d["bus_primary"]]
        bus_secondary = bus_number_to_bus[d["bus_secondary"]]
        bus_tertiary = bus_number_to_bus[d["bus_tertiary"]]
        star_bus = bus_number_to_bus[d["star_bus"]]

        name = _get_name(d, bus_primary, bus_secondary, bus_tertiary)
        value = make_3w_transformer(
            name,
            d,
            bus_primary,
            bus_secondary,
            bus_tertiary,
            star_bus,
        )

        add_component!(sys, value; skip_validation = SKIP_PM_VALIDATION)

        _attach_impedance_correction_tables!(sys, value, name, d, ict_instances)
    end
end

function make_dcline(name::String, d::Dict, bus_f::ACBus, bus_t::ACBus, source_type::String)
    if source_type == "pti"
        return TwoTerminalLCCLine(;
            name = name,
            available = d["available"],
            arc = Arc(bus_f, bus_t),
            active_power_flow = get(d, "pf", 0.0),
            r = d["r"],
            transfer_setpoint = d["transfer_setpoint"],
            scheduled_dc_voltage = d["scheduled_dc_voltage"],
            rectifier_bridges = d["rectifier_bridges"],
            rectifier_delay_angle_limits = d["rectifier_delay_angle_limits"],
            rectifier_rc = d["rectifier_rc"],
            rectifier_xc = d["rectifier_xc"],
            rectifier_base_voltage = d["rectifier_base_voltage"],
            inverter_bridges = d["inverter_bridges"],
            inverter_extinction_angle_limits = d["inverter_extinction_angle_limits"],
            inverter_rc = d["inverter_rc"],
            inverter_xc = d["inverter_xc"],
            inverter_base_voltage = d["inverter_base_voltage"],
            power_mode = d["power_mode"],
            switch_mode_voltage = d["switch_mode_voltage"],
            compounding_resistance = d["compounding_resistance"],
            min_compounding_voltage = d["min_compounding_voltage"],
            rectifier_transformer_ratio = d["rectifier_transformer_ratio"],
            rectifier_tap_setting = d["rectifier_tap_setting"],
            rectifier_tap_limits = d["rectifier_tap_limits"],
            rectifier_tap_step = d["rectifier_tap_step"],
            rectifier_delay_angle = d["rectifier_delay_angle"],
            rectifier_capacitor_reactance = d["rectifier_capacitor_reactance"],
            inverter_transformer_ratio = d["inverter_transformer_ratio"],
            inverter_tap_setting = d["inverter_tap_setting"],
            inverter_tap_limits = d["inverter_tap_limits"],
            inverter_tap_step = d["inverter_tap_step"],
            inverter_extinction_angle = d["inverter_extinction_angle"],
            inverter_capacitor_reactance = d["inverter_capacitor_reactance"],
            active_power_limits_from = d["active_power_limits_from"],
            active_power_limits_to = d["active_power_limits_to"],
            reactive_power_limits_from = d["reactive_power_limits_from"],
            reactive_power_limits_to = d["reactive_power_limits_to"],
            loss = LinearCurve(d["loss1"], d["loss0"]),
            ext = get(d, "ext", Dict{String, Any}()),
        )
    elseif source_type == "matpower"
        return TwoTerminalGenericHVDCLine(;
            name = name,
            available = d["br_status"] == 1,
            active_power_flow = get(d, "pf", 0.0),
            arc = Arc(bus_f, bus_t),
            active_power_limits_from = (min = d["pminf"], max = d["pmaxf"]),
            active_power_limits_to = (min = d["pmint"], max = d["pmaxt"]),
            reactive_power_limits_from = (min = d["qminf"], max = d["qmaxf"]),
            reactive_power_limits_to = (min = d["qmint"], max = d["qmaxt"]),
            loss = LinearCurve(d["loss1"], d["loss0"]),
        )
    else
        error("Not supported source type for DC lines: $source_type")
    end
end

function read_dcline!(
    sys::System,
    data::Dict,
    bus_number_to_bus::Dict{Int, ACBus},
    source_type::String;
    kwargs...,
)
    @info "Reading DC Line data"
    if !haskey(data, "dcline")
        @info "There is no DClines data in this file"
        return
    end

    _get_name = get(kwargs, :dcline_name_formatter, _get_pm_branch_name)

    for (d_key, d) in data["dcline"]
        d["name"] = get(d, "name", d_key)
        bus_f = bus_number_to_bus[d["f_bus"]]
        bus_t = bus_number_to_bus[d["t_bus"]]
        name = _get_name(d, bus_f, bus_t)
        dcline = make_dcline(name, d, bus_f, bus_t, source_type)
        add_component!(sys, dcline; skip_validation = SKIP_PM_VALIDATION)
    end
end

# PSS/E encodes "no remote regulated bus" as REMOT = 0, but PSY's
# `remote_bus_control_*` is `Union{Nothing, Int}` with a valid range of `>= 1`, and spells
# local terminal-bus regulation as `nothing`. Passing 0 straight through trips the
# descriptor's `error` validation action.
function _psse_remote_bus(d::Dict, key::String)
    remote_bus = get(get(d, "ext", Dict()), key, 0)
    if iszero(remote_bus)
        return nothing
    end
    return remote_bus
end

function make_vscline(name::String, d::Dict, bus_f::ACBus, bus_t::ACBus)
    return TwoTerminalVSCLine(;
        name = name,
        available = d["available"],
        arc = Arc(bus_f, bus_t),
        active_power_flow = get(d, "pf", 0.0),
        rating = d["rating"],
        active_power_limits_from = (min = d["pminf"], max = d["pmaxf"]),
        active_power_limits_to = (min = d["pmint"], max = d["pmaxt"]),
        g = d["r"] == 0.0 ? 0.0 : 1.0 / d["r"],
        rated_dc_voltage = d["rated_dc_voltage"],
        dc_current = get(d, "if", 0.0),
        reactive_power_from = get(d, "qf", 0.0),
        dc_control_from = if d["dc_voltage_control_from"]
            VSCDCControlModes.DC_VOLTAGE
        else
            VSCDCControlModes.DC_POWER
        end,
        ac_control_from = if d["ac_voltage_control_from"]
            VSCACControlModes.AC_VOLTAGE
        else
            VSCACControlModes.AC_REACTIVE_POWER
        end,
        dc_setpoint_from = d["dc_setpoint_from"],
        ac_setpoint_from = d["ac_setpoint_from"],
        converter_loss_from = d["converter_loss_from"],
        max_dc_current_from = d["max_dc_current_from"],
        rating_from = d["rating_from"],
        reactive_power_limits_from = (min = d["qminf"], max = d["qmaxf"]),
        power_factor_weighting_fraction_from = d["power_factor_weighting_fraction_from"],
        remote_bus_control_from = _psse_remote_bus(d, "REMOT_FROM"),
        rmpct_from = get(get(d, "ext", Dict()), "RMPCT_FROM", 100.0),
        reactive_power_to = get(d, "qt", 0.0),
        dc_control_to = if d["dc_voltage_control_to"]
            VSCDCControlModes.DC_VOLTAGE
        else
            VSCDCControlModes.DC_POWER
        end,
        ac_control_to = if d["ac_voltage_control_to"]
            VSCACControlModes.AC_VOLTAGE
        else
            VSCACControlModes.AC_REACTIVE_POWER
        end,
        dc_setpoint_to = d["dc_setpoint_to"],
        ac_setpoint_to = d["ac_setpoint_to"],
        converter_loss_to = d["converter_loss_to"],
        max_dc_current_to = d["max_dc_current_to"],
        rating_to = d["rating_to"],
        remote_bus_control_to = _psse_remote_bus(d, "REMOT_TO"),
        rmpct_to = get(get(d, "ext", Dict()), "RMPCT_TO", 100.0),
        reactive_power_limits_to = (min = d["qmint"], max = d["qmaxt"]),
        power_factor_weighting_fraction_to = d["power_factor_weighting_fraction_to"],
        ext = get(d, "ext", Dict{String, Any}()),
    )
end

function read_vscline!(
    sys::System,
    data::Dict,
    bus_number_to_bus::Dict{Int, ACBus};
    kwargs...,
)
    @info "Reading VSC Line data"
    if !haskey(data, "vscline")
        @info "There is no VSC lines data in this file"
        return
    end

    _get_name = get(kwargs, :vsc_line_name_formatter, _get_pm_branch_name)

    for (d_key, d) in data["vscline"]
        d["name"] = get(d, "name", d_key)
        if !haskey(bus_number_to_bus, d["f_bus"]) || !haskey(bus_number_to_bus, d["t_bus"])
            @warn "VSC line $d_key references undefined bus(es) (from = $(d["f_bus"]), to = $(d["t_bus"])); skipping"
            continue
        end
        bus_f = bus_number_to_bus[d["f_bus"]]
        bus_t = bus_number_to_bus[d["t_bus"]]
        name = _get_name(d, bus_f, bus_t)
        vscline = make_vscline(name, d, bus_f, bus_t)
        add_component!(sys, vscline; skip_validation = SKIP_PM_VALIDATION)
    end
end

function make_switched_shunt(name::String, d::Dict, bus::ACBus)
    params = Dict(
        :name => name,
        :available => Bool(d["status"]),
        :bus => bus,
        :Y => (d["gs"] + d["bs"]im),
        :number_of_steps => d["step_number"],
        :Y_increase => d["y_increment"],
        :admittance_limits => d["admittance_limits"],
        :control_mode => SwitchedAdmittanceControlMode(d["control_mode"]),
        :regulated_bus_number => d["regulated_bus_number"],
        :ext => d["ext"],
    )

    if haskey(d, "initial_status")
        params[:initial_status] = d["initial_status"]
    end

    return SwitchedAdmittance(; params...)
end

function read_switched_shunt!(
    sys::System,
    data::Dict,
    bus_number_to_bus::Dict{Int, ACBus};
    kwargs...,
)
    @info "Reading switched shunt data"
    if !haskey(data, "switched_shunt")
        @info "There is no switched shunt data in this file"
        return
    end

    _get_name = get(kwargs, :switched_shunt_name_formatter, _get_pm_dict_name)

    for (d_key, d) in data["switched_shunt"]
        d["name"] = get(d, "name", d_key)
        name = _get_name(d)
        bus = bus_number_to_bus[d["shunt_bus"]]
        shunt = make_switched_shunt(name, d, bus)

        add_component!(sys, shunt; skip_validation = SKIP_PM_VALIDATION)
    end
end

function make_shunt(name::String, d::Dict, bus::ACBus)
    return FixedAdmittance(;
        name = name,
        available = Bool(d["status"]),
        bus = bus,
        Y = (d["gs"] + d["bs"]im),
    )
end

function make_facts(name::String, d::Dict, bus::ACBus)
    if d["tbus"] != 0
        @warn "Series FACTs not supported."
    end

    if d["control_mode"] > 3
        throw(DataFormatError("Operation mode not supported."))
    end

    return FACTSControlDevice(;
        name = name,
        available = Bool(d["available"]),
        bus = bus,
        control_mode = d["control_mode"],
        voltage_setpoint = d["voltage_setpoint"],
        max_shunt_current = d["max_shunt_current"],
        regulated_bus_number = d["regulated_bus_number"],
        ext = get(d, "ext", Dict{String, Any}()),
    )
end

function read_facts!(
    sys::System,
    data::Dict,
    bus_number_to_bus::Dict{Int, ACBus};
    kwargs...,
)
    @info "Reading FACTS data"
    if !haskey(data, "facts")
        @info "There is no facts data in this file"
        return
    end

    _get_name = get(kwargs, :bus_name_formatter, _get_pm_dict_name)

    for (d_key, d) in data["facts"]
        d["name"] = get(d, "name", d_key)
        name = _get_name(d)
        bus = bus_number_to_bus[d["bus"]]
        full_name = "$(d["bus"])_$(name)"
        facts = make_facts(full_name, d, bus)

        add_component!(sys, facts; skip_validation = SKIP_PM_VALIDATION)
    end
end

function read_shunt!(
    sys::System,
    data::Dict,
    bus_number_to_bus::Dict{Int, ACBus};
    kwargs...,
)
    @info "Reading shunt data"
    if !haskey(data, "shunt")
        @info "There is no shunt data in this file"
        return
    end

    _get_name = get(kwargs, :shunt_name_formatter, _get_pm_dict_name)

    for (d_key, d) in data["shunt"]
        d["name"] = get(d, "name", d_key)
        name = _get_name(d)
        bus = bus_number_to_bus[d["shunt_bus"]]
        shunt = make_shunt(name, d, bus)

        add_component!(sys, shunt; skip_validation = SKIP_PM_VALIDATION)
    end
end

function read_storage!(
    sys::System,
    data::Dict,
    bus_number_to_bus::Dict{Int, ACBus};
    kwargs...,
)
    @info "Reading storage data"
    if !haskey(data, "storage")
        @info "There is no storage data in this file"
        return
    end

    _get_name = get(kwargs, :gen_name_formatter, _get_pm_dict_name)

    for (d_key, d) in data["storage"]
        d["name"] = get(d, "name", d_key)
        name = _get_name(d)
        bus = bus_number_to_bus[d["storage_bus"]]
        storage = make_generic_battery(name, d, bus)

        add_component!(sys, storage; skip_validation = SKIP_PM_VALIDATION)
    end
end
