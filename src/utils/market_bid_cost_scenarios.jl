# Changes to test systems that set up market bid cost scenarios for the operations and
# simulation test suites. Every power series these functions write is in MW, so its size
# does not depend on the owner's base_power.

const MULTISTART_UNIT = "115_STEAM_1"
const MULTISTART_BACKUP = "Alta"
const MULTISTART_LOAD = "Bus4"
const MULTISTART_BACKUP_MAX_MW = 10.0
const MULTISTART_ON_LOAD_MW = 14.0
const MULTISTART_OFF_LOAD_MW = 3.0

# A forecast with the shape of the forecasts of `sys` that holds `value` at every step.
function _constant_forecast(sys::PSY.System, name::String, value; kwargs...)
    resolution = only(PSY.get_time_series_resolutions(sys))
    horizon_count = IS.get_horizon_count(PSY.get_forecast_horizon(sys), resolution)
    data = SortedDict(
        t => fill(value, horizon_count) for t in PSY.get_forecast_initial_times(sys)
    )
    return PSY.Deterministic(;
        name = name,
        data = data,
        resolution = resolution,
        interval = PSY.get_forecast_interval(sys),
        kwargs...,
    )
end

"""
Replace the `Deterministic` series `name` of `component` with its values times `factor`.
The new series keeps the labels of the old one.
"""
function scale_time_series!(sys::PSY.System, component, name::String, factor)
    isone(factor) && return
    ts = PSY.get_time_series(PSY.Deterministic, component, name)
    scaled_ts = PSY.Deterministic(
        ts,
        SortedDict(k => v .* factor for (k, v) in IS.get_data(ts)),
    )
    PSY.remove_time_series!(sys, PSY.Deterministic, component, name)
    PSY.add_time_series!(sys, component, scaled_ts)
    return
end

"""
Replace the `max_active_power` series of `component` with a constant at the peak of the
series, in MW.
"""
function set_constant_max_active_power!(sys::PSY.System, component::PSY.Device)
    ts = PSY.get_time_series(PSY.Deterministic, component, "max_active_power")
    peak_mw =
        maximum(maximum, values(IS.get_data(ts))) *
        PSY.get_time_series_conversion_factor(component, ts, u"MW"; quantity = :ActivePower)
    constant = PSY.Deterministic(;
        name = "max_active_power",
        data = SortedDict(k => fill(peak_mw, length(v)) for (k, v) in IS.get_data(ts)),
        resolution = IS.get_resolution(ts),
        interval = IS.get_interval(ts),
        natural_units("active_power", "MW")...,
    )
    PSY.remove_time_series!(sys, PSY.Deterministic, component, "max_active_power")
    PSY.add_time_series!(sys, component, constant)
    return
end

"""
Move the market bid cost of `old_component` to `new_component`. The time series of a
`MarketBidTimeSeriesCost` are copied to `new_component`.
"""
function transfer_market_bid_cost!(
    new_component::PSY.Device,
    old_component::PSY.Device,
    sys::PSY.System,
)
    cost = deepcopy(PSY.get_operation_cost(old_component))
    PSY.set_operation_cost!(
        new_component,
        _rehomed_cost(cost, old_component, sys, new_component),
    )
    return
end

_rehomed_cost(cost::PSY.MarketBidCost, ::PSY.Device, ::PSY.System, ::PSY.Device) = cost

function _rehomed_cost(
    cost::PSY.MarketBidTimeSeriesCost,
    old_component::PSY.Device,
    sys::PSY.System,
    new_component::PSY.Device,
)
    rehome(key::IS.TimeSeriesKey) = PSY.add_time_series!(
        sys,
        new_component,
        deepcopy(PSY.get_time_series(old_component, key)),
    )
    return PSY.MarketBidTimeSeriesCost(;
        minimum_energy_offer = PSY.TimeSeriesLinearCurve(
            rehome(IS.get_time_series_key(PSY.get_minimum_energy_offer(cost))),
        ),
        start_up = rehome(PSY.get_start_up(cost)),
        shut_down = PSY.TimeSeriesLinearCurve(
            rehome(IS.get_time_series_key(PSY.get_shut_down(cost))),
        ),
        incremental_offer_curves =
        _rehomed_offer_curve(PSY.get_incremental_offer_curves(cost), rehome),
        decremental_offer_curves =
        _rehomed_offer_curve(PSY.get_decremental_offer_curves(cost), rehome),
        ancillary_service_offers = PSY.get_ancillary_service_offers(cost),
        incremental_slope = PSY.get_incremental_slope(cost),
        decremental_slope = PSY.get_decremental_slope(cost),
        curve_style = PSY.get_curve_style(cost),
    )
end

function _rehomed_offer_curve(
    curve::PSY.CostCurve{<:PSY.TimeSeriesPiecewiseIncrementalCurve},
    rehome,
)
    value_curve = PSY.get_value_curve(curve)
    pwl_key = rehome(IS.get_time_series_key(value_curve))
    initial_key = IS.get_initial_input(value_curve)
    if isnothing(initial_key)
        new_initial_key = nothing
    else
        new_initial_key = rehome(initial_key)
    end
    return PSY.make_market_bid_ts_curve(
        pwl_key,
        new_initial_key,
        PSY.get_power_units(curve),
    )
end

"""Set the start-up and shut-down costs of the market bid cost of `component` to zero."""
function zero_startup_shutdown_costs!(sys::PSY.System, component::PSY.Device)
    _zero_startup_shutdown_costs!(sys, component, PSY.get_operation_cost(component))
    return
end

function _zero_startup_shutdown_costs!(
    ::PSY.System,
    ::PSY.Device,
    cost::PSY.MarketBidCost,
)
    PSY.set_start_up!(cost, (hot = 0.0, warm = 0.0, cold = 0.0))
    PSY.set_shut_down!(cost, PSY.LinearCurve(0.0))
    return
end

function _zero_startup_shutdown_costs!(
    sys::PSY.System,
    component::PSY.Device,
    cost::PSY.MarketBidTimeSeriesCost,
)
    start_up = _constant_forecast(sys, "zeroed_start_up", (0.0, 0.0, 0.0))
    shut_down = _constant_forecast(sys, "zeroed_shut_down", PSY.LinearFunctionData(0.0))
    PSY.set_start_up!(cost, PSY.add_time_series!(sys, component, start_up))
    PSY.set_shut_down!(
        cost,
        PSY.TimeSeriesLinearCurve(PSY.add_time_series!(sys, component, shut_down)),
    )
    return
end

"""
Replace `unit` with a `RenewableDispatch` named `RG1` that takes its market bid cost, with
zero start-up and shut-down costs. Its `max_active_power` series is in MW: the maximum of
`unit` when `use_thermal_max_power`, otherwise `magnitude` plus up to `random_variation`
times the rating, drawn from `rng`. The series has the windows of the first load's series.
"""
function replace_with_renewable!(
    sys::PSY.System,
    unit::PSY.Generator;
    use_thermal_max_power = false,
    magnitude = 1.0,
    random_variation = 0.1,
    rng = Random.default_rng(),
)
    renewable = PSY.RenewableDispatch(;
        name = "RG1",
        available = true,
        bus = PSY.get_bus(unit),
        active_power = PSY.get_active_power(unit, u"CU"),
        reactive_power = PSY.get_reactive_power(unit, u"CU"),
        rating = PSY.get_rating(unit, u"CU"),
        prime_mover_type = PSY.PrimeMovers.PVe,
        reactive_power_limits = PSY.get_reactive_power_limits(unit, u"CU"),
        power_factor = 0.9,
        operation_cost = deepcopy(PSY.get_operation_cost(unit)),
        base_power = PSY.get_base_power(unit),
        input_basis = u"CU",
    )
    PSY.add_component!(sys, renewable)
    transfer_market_bid_cost!(renewable, unit, sys)
    max_mw = PSY.get_active_power_limits(unit, u"MW").max
    PSY.remove_component!(sys, unit)
    zero_startup_shutdown_costs!(sys, renewable)

    # A native `Deterministic`, not a transformed `SingleTimeSeries`: the market bid cost
    # series of these systems are native, and a system cannot mix the two forecast types.
    load = first(PSY.get_components(PSY.PowerLoad, sys))
    load_ts = PSY.get_time_series(PSY.Deterministic, load, "max_active_power")
    interval = IS.get_interval(load_ts)
    num_windows = length(IS.get_data(load_ts))
    num_steps = floor(Int, IS.get_horizon(load_ts) / interval)
    total_steps = num_windows + num_steps - 1
    if use_thermal_max_power
        profile = fill(max_mw, total_steps)
    else
        profile =
            (magnitude .+ random_variation .* rand(rng, total_steps)) .*
            PSY.get_max_active_power(renewable, u"MW")
    end
    start = IS.get_initial_timestamp(load_ts)
    data = SortedDict(
        start + (w - 1) * interval => profile[w:(w + num_steps - 1)] for w in 1:num_windows
    )
    PSY.add_time_series!(
        sys,
        renewable,
        PSY.Deterministic(;
            name = "max_active_power",
            data = data,
            resolution = interval,
            interval = interval,
            natural_units("active_power", "MW")...,
        ),
    )
    return renewable
end

"""
Reduce `sys` (`c_sys5_pglib`) to the multistart unit, one backup unit and one load, and set
the load so that it alone decides when the multistart unit runs. In each hour of
`off_hours` the load is below the minimum power of the multistart unit, so the unit must be
off. In every other hour the load is above the capacity of the backup unit, so the unit
must be on. Every forecast window has the same profile, in MW. The backup unit is cheaper,
so the multistart unit runs at its minimum power and its ramp limits do not bind.
"""
function force_multistart_commitment!(sys::PSY.System, off_hours)
    keep = (MULTISTART_UNIT, MULTISTART_BACKUP, MULTISTART_LOAD)
    for component in collect(PSY.get_components(PSY.StaticInjection, sys))
        PSY.get_name(component) in keep || PSY.remove_component!(sys, component)
    end

    backup = PSY.get_component(PSY.ThermalStandard, sys, MULTISTART_BACKUP)
    PSY.set_active_power_limits!(
        backup,
        (min = 0.0 * u"MW", max = MULTISTART_BACKUP_MAX_MW * u"MW"),
    )
    PSY.set_operation_cost!(
        backup,
        PSY.ThermalGenerationCost(PSY.CostCurve(PSY.LinearCurve(1.0)), 0.0, 0.0, 0.0),
    )

    load = PSY.get_component(PSY.PowerLoad, sys, MULTISTART_LOAD)
    PSY.set_max_active_power!(load, MULTISTART_ON_LOAD_MW * u"MW")
    resolution = only(PSY.get_time_series_resolutions(sys))
    horizon_count = IS.get_horizon_count(PSY.get_forecast_horizon(sys), resolution)
    all(h -> 1 <= h <= horizon_count, off_hours) ||
        throw(ArgumentError("off_hours $off_hours are outside 1:$horizon_count"))
    profile = [
        ifelse(h in off_hours, MULTISTART_OFF_LOAD_MW, MULTISTART_ON_LOAD_MW) for
        h in 1:horizon_count
    ]
    load_ts = PSY.Deterministic(;
        name = "max_active_power",
        data = SortedDict(
            t => copy(profile) for t in PSY.get_forecast_initial_times(sys)
        ),
        resolution = resolution,
        interval = PSY.get_forecast_interval(sys),
        natural_units("active_power", "MW")...,
    )
    PSY.remove_time_series!(sys, PSY.Deterministic, load, "max_active_power")
    PSY.add_time_series!(sys, load, load_ts)
    return sys
end
