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

import PowerSystems: ReserveDemandCurve, ReserveDirection
import PowerSystems:
    MarketBidCost, CostCurve, PiecewiseIncrementalCurve, LinearCurve, Service

# ---------------------------------------------------------------------------
# ReserveDemandCurve – variable field: Nothing → ZERO_OFFER_CURVE
#
# Old call (data_5bus_pu.jl):
#   ReserveDemandCurve{ReserveUp}(nothing, "ORDC1", true, 0.6)
#
# PSY6 no longer accepts Nothing for `variable`; it must be a
# CostCurve{PiecewiseIncrementalCurve}.  We substitute ZERO_OFFER_CURVE,
# mirroring what PSY6's own demo constructor (::Nothing) does.
# ---------------------------------------------------------------------------
const _ZERO_OFFER_CURVE = CostCurve(PiecewiseIncrementalCurve(0.0, [0.0, 0.0], [0.0]))

function PowerSystems.ReserveDemandCurve{T}(
    ::Nothing,
    name::String,
    available::Bool,
    time_frame::Real,
    sustained_time::Real = 3600.0,
    max_participation_factor::Real = 1.0,
    deployed_fraction::Real = 0.0,
    ext::Dict{String, Any} = Dict{String, Any}(),
) where {T <: ReserveDirection}
    ReserveDemandCurve{T}(
        _ZERO_OFFER_CURVE,
        name,
        available,
        Float64(time_frame),
        Float64(sustained_time),
        Float64(max_participation_factor),
        Float64(deployed_fraction),
        ext,
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
