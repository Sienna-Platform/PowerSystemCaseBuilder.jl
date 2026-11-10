# How the builders label time series: per unit on the owner's base or in natural units,
# and the scaling that converts test system data into the latter.

"""
Keyword arguments declaring a time series stored per unit on its owner's own base.

Replaces `scaling_factor_multiplier`, which InfrastructureSystems removed. A normalized
profile used to be stored bare next to the name of an accessor, and every read multiplied it
by that accessor's value on the owner. The profile is still stored the same way — one shared
array many components can point at — but the storage now *declares* what it is:
`per_unit_of` names the component field the values are a fraction of — `base_power` for
power, `storage_capacity` for a battery's energy — which makes them per unit on the
component's own base (IS derives `unit_system = CU` from it), and `quantity_kind` names the
physical quantity they scale to. That
carries the same meaning without a function name for the reader to resolve, and leaves the
scaling to the consumer.

`units` stays `nothing`: a per-unit basis is not a units label.
"""
component_base(quantity_kind::AbstractString, per_unit_of::AbstractString = "base_power") =
    (
        units = nothing,
        quantity_kind = quantity_kind,
        per_unit_of = per_unit_of,
    )

"""Keyword arguments declaring a time series stored in the natural `units` of its quantity."""
natural_units(quantity_kind::AbstractString, units::AbstractString) =
    (units = units, quantity_kind = quantity_kind)

"""
Flows of an `ENERGY` reservoir in the test system data, in MW for [`ENERGY_FLOW`](@ref).
The test system data states them per unit of the system base (`data_5bus_pu.jl`: "per-unit
(100MW base)").
"""
in_mw(sys::PSY.System, data) = scaled(data, PSY.get_base_power(sys))

"""
A reserve's requirement profile in MW. PowerSystems takes a service's series in natural
units only, and the test system data's profiles are fractions of the reserve's own
`requirement`, so they are scaled by it, as PowerTableDataParser does for tabular data. The
`requirement` field keeps its value.
"""
requirement_in_mw(serv::PSY.Service, data) =
    scaled(data, PSY.get_requirement(serv, u"MW"))

"""Time series data, a `TimeArray` or a forecast's windows, times `factor`."""
scaled(ta::TimeSeries.TimeArray, factor) = ta .* factor
scaled(data::AbstractDict, factor) =
    SortedDict{Dates.DateTime, TimeSeries.TimeArray}(
        k => scaled(v, factor) for (k, v) in data
    )

"""
The quantity a profile normalized against a reservoir's storage capacity scales to.

Depends on the reservoir: `level_data_type` decides whether its levels are accounted in
energy, in volume, or as a head. `PowerTableDataParser` owns the mapping so the fixtures and
the table parser cannot drift apart on what a reservoir-normalized series means.
"""
reservoir_level_quantity(reservoir::PSY.HydroReservoir) =
    PowerTableDataParser.quantity_kind_for_multiplier(
        "get_storage_capacity",
        () -> string(PSY.get_level_data_type(reservoir)),
    )

"""
An `EnergyReservoirStorage` has no `level_data_type` to choose from: its `storage_capacity`
is canonically MWh, with `conversion_factor` scaling a non-MWh medium into it. So its levels
are energy however the medium is measured.
"""
reservoir_level_quantity(::PSY.EnergyReservoirStorage) = "energy"

"""
How a level profile normalized against its owner's capacity is stored, as the keyword
arguments [`reservoir_level_labels`](@ref) and the values [`reservoir_level_values`](@ref).

A battery's stays per unit of its `storage_capacity`. PowerSystems takes a reservoir's levels
in natural units only, so its profile is scaled by `storage_level_limits.max` into the natural
unit of its level quantity.
"""
reservoir_level_labels(storage::PSY.EnergyReservoirStorage) =
    component_base(reservoir_level_quantity(storage), "storage_capacity")
function reservoir_level_labels(reservoir::PSY.HydroReservoir)
    quantity = reservoir_level_quantity(reservoir)
    return natural_units(quantity, PowerTableDataParser.RESERVOIR_LEVEL_UNITS[quantity])
end

"""See [`reservoir_level_labels`](@ref)."""
reservoir_level_values(::PSY.EnergyReservoirStorage, data) = data
reservoir_level_values(reservoir::PSY.HydroReservoir, data) =
    scaled(data, PSY.get_storage_level_limits(reservoir).max)
