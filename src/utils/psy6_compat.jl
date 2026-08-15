# Compatibility shims for PSY6 breaking changes.
#
# PSY6 intentionally tightened the field types of MarketBidCost and
# ReserveDemandCurve.  The PowerSystemsTestData artifact files that PSCB
# includes still call the old signatures (Float64 for cost scalars, Nothing
# for optional curve fields).  Rather than patching the artifact (which is
# external and version-pinned), we add method overloads here that convert
# the old argument types to what PSY6 now expects.
#
# This file must be included AFTER `definitions.jl` (so DATA_DIR is defined)
# but BEFORE `system_library.jl` (which includes the artifact files).

import PowerSystems: ReserveDirection
import PowerSystems:
    MarketBidCost, CostCurve, PiecewiseIncrementalCurve, LinearCurve, Service
import PowerSystems: OnlineReserve, OfflineReserve

# ---------------------------------------------------------------------------
# Reserve types renamed in the PSY6 reserve redesign.
#
# The artifact data (data_5bus_pu.jl) still constructs ConstantReserve,
# VariableReserve, and VariableReserveNonSpinning, all replaced by
# OnlineReserve / OfflineReserve. The names alias directly; ConstantReserve's
# 8-argument positional call also needs an adapter below because OnlineReserve
# inserts `variable` (the ORDC) at position 5.
# ---------------------------------------------------------------------------
const ConstantReserve = OnlineReserve
const VariableReserve = OnlineReserve
const VariableReserveNonSpinning = OfflineReserve

# Old call (data_5bus_pu.jl):
#   ConstantReserve{ReserveUp}(name, available, time_frame, requirement,
#                              sustained_time, max_output_fraction,
#                              max_participation_factor, deployed_fraction)
function PowerSystems.OnlineReserve{T}(
    name::String,
    available::Bool,
    time_frame::Real,
    requirement::Real,
    sustained_time::Real,
    max_output_fraction::Real,
    max_participation_factor::Real,
    deployed_fraction::Real,
) where {T <: ReserveDirection}
    return OnlineReserve{T}(
        name,
        available,
        Float64(time_frame),
        Float64(requirement),
        _ZERO_OFFER_CURVE,
        Float64(sustained_time),
        Float64(max_output_fraction),
        Float64(max_participation_factor),
        Float64(deployed_fraction),
    )
end

# ---------------------------------------------------------------------------
# ReserveDemandCurve retired: an Operating Reserve Demand Curve is no longer its own
# type, it is an OnlineReserve whose `variable` holds the curve.
#
# Old call (data_5bus_pu.jl):
#   ReserveDemandCurve{ReserveUp}(nothing, "ORDC1", true, 0.6)
#
# The artifact passes `nothing` because the old type took its curve later, through
# `set_variable_cost!`. `has_demand_curve` is what now distinguishes an ORDC reserve, and
# it tests the curve's x-span, so constructing with ZERO_OFFER_CURVE would leave the
# reserve indistinguishable from a plain one and the library's ORDC loops would skip it.
# Build it with a placeholder spanning curve instead; the library overwrites the values
# with the real ORDC curve immediately afterwards.
# ---------------------------------------------------------------------------
const _ZERO_OFFER_CURVE = CostCurve(PiecewiseIncrementalCurve(0.0, [0.0, 0.0], [0.0]))
const _PLACEHOLDER_DEMAND_CURVE =
    CostCurve(PiecewiseIncrementalCurve(0.0, [0.0, 1.0], [0.0]))

const ReserveDemandCurve = OnlineReserve

function PowerSystems.OnlineReserve{T}(
    ::Nothing,
    name::String,
    available::Bool,
    time_frame::Real,
    sustained_time::Real = 3600.0,
    max_participation_factor::Real = 1.0,
    deployed_fraction::Real = 0.0,
    ext::Dict{String, Any} = Dict{String, Any}(),
) where {T <: ReserveDirection}
    return OnlineReserve{T}(;
        name = name,
        available = available,
        time_frame = Float64(time_frame),
        variable = _PLACEHOLDER_DEMAND_CURVE,
        sustained_time = Float64(sustained_time),
        max_participation_factor = Float64(max_participation_factor),
        deployed_fraction = Float64(deployed_fraction),
        ext = ext,
    )
end

# ---------------------------------------------------------------------------
# MarketBidCost – no_load_cost/shut_down: Float64 → LinearCurve
#                 incremental/decremental offer curves: Nothing → ZERO_OFFER_CURVE
#
# Old calls (generation_cost_function_data.jl):
#   MarketBidCost(30.0, (hot=1.5, warm=1.5, cold=1.5), 0.75,
#                 CostCurve(PiecewiseIncrementalCurve(...)), nothing,
#                 Vector{Service}())
#   MarketBidCost(30.0, (hot=1.5, warm=1.5, cold=1.5), 0.75,
#                 nothing, nothing, Vector{Service}())
#
# PSY6 now requires no_load_cost::LinearCurve and shut_down::LinearCurve, and
# neither incremental_offer_curves nor decremental_offer_curves may be Nothing.
# ---------------------------------------------------------------------------
function PowerSystems.MarketBidCost(
    no_load_cost::Float64,
    start_up::NamedTuple,
    shut_down::Float64,
    incremental_offer_curves::Union{Nothing, CostCurve{PiecewiseIncrementalCurve}},
    decremental_offer_curves::Union{Nothing, CostCurve{PiecewiseIncrementalCurve}},
    ancillary_service_offers::Vector{<:Service},
)
    MarketBidCost(
        LinearCurve(no_load_cost),
        start_up,
        LinearCurve(shut_down),
        something(incremental_offer_curves, _ZERO_OFFER_CURVE),
        something(decremental_offer_curves, _ZERO_OFFER_CURVE),
        ancillary_service_offers,
    )
end

# ---------------------------------------------------------------------------
# set_variable_cost! – time series overload removed in PSY6
#
# Old call (generation_cost_function_data.jl):
#   set_variable_cost!(sys, component, ::Deterministic, ::UnitSystem)
#   set_variable_cost!(sys, component, ::SingleTimeSeries, ::UnitSystem)
#
# PSY6 removed the TimeSeriesData overload of set_variable_cost! for
# StaticInjection components with MarketBidCost. Time-varying market bid
# costs must now be attached via add_time_series! directly. The power_units
# argument is dropped — units are carried inside the time series data itself.
# ---------------------------------------------------------------------------
function PowerSystems.set_variable_cost!(
    sys::PowerSystems.System,
    component::PowerSystems.StaticInjection,
    data::InfrastructureSystems.TimeSeriesData,
    power_units::PowerSystems.UnitSystem = PowerSystems.UnitSystem.NATURAL_UNITS,
)
    PowerSystems.add_time_series!(sys, component, data)
end
