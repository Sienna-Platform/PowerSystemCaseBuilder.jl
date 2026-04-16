function add_static_outage_data!(sys::PSY.System, gen_for_data::DataFrame)
    for row in DataFrames.eachrow(gen_for_data)
        λ, μ = rate_to_probability(row.FOR, row["MTTR Hr"])
        transition_data = PSY.GeometricDistributionForcedOutage(;
            mean_time_to_recovery = row["MTTR Hr"],
            outage_transition_probability = λ,
        )
        comp = PSY.get_component(PSY.Generator, sys, row["GEN UID"])

        if !isnothing(comp)
            PSY.add_supplemental_attribute!(sys, comp, transition_data)
            @debug "Added outage data supplemental attribute to $(row["GEN UID"]) generator"
        else
            @warn "$(row["GEN UID"]) generator doesn't exist in the System."
        end
    end
end

function add_timeseries_outage_data!(sys::PSY.System, rts_outage_ts_data::DataFrame)
    # Time series timestamps
    ts_timestamps, first_timestamp, step = get_ts_timestamps(sys)

    # Add λ and μ time series 
    for row in DataFrames.eachrow(rts_outage_ts_data)
        comp = PSY.get_component(PSY.Generator, sys, row.Unit)
        λ_vals = Float64[]
        μ_vals = Float64[]
        for i in range(0; length = 12)
            next_timestamp = first_timestamp + Dates.Month(i)
            λ, μ = rate_to_probability(row[3 + i], 48) # Assuming MTTR is 48
            # We have monthly outage rates, so we need to fill in time series based on the 
            # resolution of the SingleTimeSeries
            append!(
                λ_vals,
                fill(λ, (daysinmonth(next_timestamp) * 24 * Int(Dates.Hour(1) / step))),
            )
            append!(
                μ_vals,
                fill(μ, (daysinmonth(next_timestamp) * 24 * Int(Dates.Hour(1) / step))),
            )
        end
        PSY.add_time_series!(
            sys,
            first(
                PSY.get_supplemental_attributes(
                    PSY.GeometricDistributionForcedOutage,
                    comp,
                ),
            ),
            PSY.SingleTimeSeries(
                "outage_probability",
                TimeSeries.TimeArray(ts_timestamps, λ_vals),
            ),
        )
        PSY.add_time_series!(
            sys,
            first(
                PSY.get_supplemental_attributes(
                    PSY.GeometricDistributionForcedOutage,
                    comp,
                ),
            ),
            PSY.SingleTimeSeries(
                "recovery_probability",
                TimeSeries.TimeArray(ts_timestamps, μ_vals),
            ),
        )
        @debug "Added outage probability and recovery probability time series to supplemental attribute of $(row["Unit"]) generator"
    end
end

function build_rts_gmlc_da_with_static_outage_data(; raw_data, kwargs...)
    sys = build_RTS_GMLC_DA_sys(; raw_data, kwargs...)
    RTS_SRC_DIR = joinpath(raw_data, "RTS_Data", "SourceData")

    gen_for_data = CSV.read(joinpath(RTS_SRC_DIR, "gen.csv"), DataFrame)
    add_static_outage_data!(sys, gen_for_data)

    return sys
end

function build_rts_gmlc_da_with_timeseries_outage_data(; raw_data, kwargs...)
    sys = build_rts_gmlc_da_with_static_outage_data(; raw_data, kwargs...)

    rts_outage_ts_data = CSV.read(
        joinpath(DATA_DIR, "spi_data", "RTS_GMLC", "RTS_Test_Outage_Time_Series_Data.csv"),
        DataFrame,
    )
    add_timeseries_outage_data!(sys, rts_outage_ts_data)

    return sys
end

function build_rts_gmlc_rt_with_static_outage_data(; raw_data, kwargs...)
    sys = build_RTS_GMLC_RT_sys(; raw_data, kwargs...)
    RTS_SRC_DIR = joinpath(raw_data, "RTS_Data", "SourceData")

    gen_for_data = CSV.read(joinpath(RTS_SRC_DIR, "gen.csv"), DataFrame)
    add_static_outage_data!(sys, gen_for_data)

    return sys
end

function build_rts_gmlc_rt_with_timeseries_outage_data(; raw_data, kwargs...)
    sys = build_rts_gmlc_rt_with_static_outage_data(; raw_data, kwargs...)

    rts_outage_ts_data = CSV.read(
        joinpath(DATA_DIR, "spi_data", "RTS_GMLC", "RTS_Test_Outage_Time_Series_Data.csv"),
        DataFrame,
    )
    add_timeseries_outage_data!(sys, rts_outage_ts_data)

    return sys
end
