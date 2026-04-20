"""
    rate_to_probability(for_gen::Float64, mttr::Int64)

Converts the forced outage rate and mean time to repair to the λ and μ parameters

# Arguments

  - `for_gen::Float64`: Forced outage rate [1/T]
  - `mttr::Int64`: Mean time to repair [T]

# Returns

  - `λ::Float64`: Transition probability from online to offline [1/T]
  - `μ::Float64`: Transition rate from offline to online [1/T]

# Reference

https://core.ac.uk/download/pdf/13643059.pdf
from https://github.com/Sienna-Platform/SiennaPRASInterface.jl/blob/main/src/util/draws/draw_helper_functions.jl
"""
function rate_to_probability(for_gen::Float64, mttr::Int64)
    if (for_gen > 1.0)
        for_gen = for_gen / 100
    end

    if for_gen == 1.0
        return (λ = 1.0, μ = 0.0)  # can we error here instead?
    end
    if mttr != 0
        μ = 1 / mttr
    else # MTTR of 0.0 doesn't make much sense.
        μ = 1.0
    end
    return (λ = (μ * for_gen) / (1 - for_gen), μ = μ)
end

function get_ts_timestamps(sys::PSY.System)
    static_ts_summary = PSY.get_static_time_series_summary_table(sys)

    first_timestamp = DateTime(static_ts_summary[1, "initial_timestamp"])
    ts_period = static_ts_summary[1, "resolution"].periods[1]
    ts_resolution = typeof(ts_period)
    ts_step = ts_resolution(ts_period.value)
    ts_count = static_ts_summary[1, "time_step_count"]
    finish_datetime = first_timestamp + ts_resolution((ts_count - 1) * ts_step)

    ts_timestamps = collect(StepRange(first_timestamp, ts_step, finish_datetime))
    return ts_timestamps, first_timestamp, ts_step
end
