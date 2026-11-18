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

"""Sets the `requirement` of reserves to `megawatts` MW; `nothing` keeps the data's values."""
set_requirement_mw!(::Nothing, reserves::PSY.Service...) = nothing
function set_requirement_mw!(megawatts::Real, reserves::PSY.Service...)
    for serv in reserves
        PSY.set_requirement!(serv, megawatts * u"MW")
    end
    return
end

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

"""
Make `device` `factor` times bigger, for scenario builders. This is a change to the system,
not a units conversion: `base_power` moves without re-expressing the per-unit fields, so
every one of them (rating, limits, CU series) scales with it, and each power series stored
in natural units is replaced by `factor` times its values, keeping its labels.

Only `SingleTimeSeries` are rescaled, so call it before `transform_single_time_series!`.
"""
function scale_capacity!(sys::PSY.System, device::PSY.Device, factor::Real)
    PSY._set_base_power!(device, factor * PSY.get_base_power(device, u"NU"))
    for md in IS.list_time_series_metadata(device)
        IS.get_quantity_kind(md) in ("active_power", "reactive_power") || continue
        IS.get_unit_system(md) isa PSY.ComponentBaseUnit && continue
        T = IS.get_time_series_type(md)
        T <: PSY.SingleTimeSeries || throw(
            ArgumentError(
                "scale_capacity! rescales SingleTimeSeries only; $(summary(device)) has " *
                "$T \"$(IS.get_name(md))\". Call it before transform_single_time_series!.",
            ),
        )
        name = IS.get_name(md)
        ta = IS.get_time_array(PSY.get_time_series(T, device, name))
        scaled_ts = PSY.SingleTimeSeries(
            name,
            TimeSeries.TimeArray(TimeSeries.timestamp(ta), TimeSeries.values(ta) .* factor);
            natural_units(IS.get_quantity_kind(md), IS.get_units(md))...,
        )
        # Replace rather than mutate: other components may share the stored array.
        PSY.remove_time_series!(sys, T, device, name)
        PSY.add_time_series!(sys, device, scaled_ts)
    end
    return device
end
