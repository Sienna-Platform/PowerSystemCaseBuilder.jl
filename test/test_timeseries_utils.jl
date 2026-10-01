"""
    check_load_profiles(sys::PSY.System, expected_by_name::AbstractDict{<:AbstractString, <:TimeSeries.TimeArray}, ::Type{PSY.SingleTimeSeries})

Check the single time series on each named power load against its expected profile.

# Arguments
- `sys::PSY.System`: System containing the power loads to check.
- `expected_by_name::AbstractDict{<:AbstractString, <:TimeSeries.TimeArray}`: Expected profile for each load name.
- `::Type{PSY.SingleTimeSeries}`: Select single time series profiles.
"""
function check_load_profiles(
    sys::PSY.System,
    expected_by_name::AbstractDict{<:AbstractString, <:TimeSeries.TimeArray},
    ::Type{PSY.SingleTimeSeries},
)
    for (load_name, expected) in expected_by_name
        load = PSY.get_component(PSY.PowerLoad, sys, load_name)
        actual = PSY.get_time_series_array(
            PSY.SingleTimeSeries,
            load,
            "max_active_power";
            ignore_scaling_factors = true,
        )
        @test TimeSeries.values(actual) == TimeSeries.values(expected)
    end
end

"""
    check_load_profiles(sys::PSY.System, expected_by_name::AbstractDict{<:AbstractString, <:AbstractVector{<:TimeSeries.TimeArray}}, ::Type{PSY.Deterministic})

Check every forecast window on each named power load against its expected profile.

# Arguments
- `sys::PSY.System`: System containing the power loads to check.
- `expected_by_name::AbstractDict{<:AbstractString, <:AbstractVector{<:TimeSeries.TimeArray}}`: Expected forecast windows for each load name.
- `::Type{PSY.Deterministic}`: Select deterministic forecast profiles.
"""
function check_load_profiles(
    sys::PSY.System,
    expected_by_name::AbstractDict{
        <:AbstractString,
        <:AbstractVector{<:TimeSeries.TimeArray},
    },
    ::Type{PSY.Deterministic},
)
    for (load_name, forecasts) in expected_by_name
        load = PSY.get_component(PSY.PowerLoad, sys, load_name)
        for expected in forecasts
            actual = PSY.get_time_series_array(
                PSY.Deterministic,
                load,
                "max_active_power";
                start_time = first(TimeSeries.timestamp(expected)),
                ignore_scaling_factors = true,
            )
            @test TimeSeries.values(actual) == TimeSeries.values(expected)
        end
    end
end
