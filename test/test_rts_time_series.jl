_build_rts(name) =
    build_system(PSISystems, name; force_build = true, skip_serialization = true)

# The SIIP pointer entries for one resolution: each names its series, its component (also
# the CSV column) and its CSV, relative to the SIIP directory.
const _SIIP_DIR = joinpath(PSB.RTS_DIR, "RTS_Data", "FormattedData", "SIIP")
_pointers(resolution_s) = filter(
    p -> p["resolution"] == resolution_s,
    PSB.JSON.parsefile(joinpath(_SIIP_DIR, "timeseries_pointers.json")),
)
_csv_column(pointer) = PSB.CSV.read(
    normpath(joinpath(_SIIP_DIR, pointer["data_file"])), PSB.DataFrame,
)[
    !,
    pointer["component_name"],
]

# The component carrying the pointer's series (a reservoir can share its turbine's name).
_series_owner(sys, pointer) = only(
    c for c in get_components_by_name(Component, sys, pointer["component_name"]) if
    has_time_series(c, SingleTimeSeries, pointer["name"])
)
_mw(c, name) = get_time_series_values(SingleTimeSeries, c, name, u"MW")
_matches(series, csv) = length(series) <= length(csv) && series ≈ csv[1:length(series)]

@testset "RTS renewable and hydro output stays within each device's maximum" begin
    # 212_CSP_1's source data peaks at 391 MW against its 200 MW maximum.
    carve_out = ("212_CSP_1",)
    for name in (
        "RTS_GMLC_DA_sys",
        "modified_RTS_GMLC_DA_sys_noForecast",
        "modified_RTS_GMLC_realization_sys",
        "AC_TWO_RTO_RTS_1Hr_sys",
        "AC_TWO_RTO_RTS_5min_sys",
    )
        sys = _build_rts(name)
        over = String[]
        for d in get_components(Union{RenewableGen, HydroGen}, sys)
            get_name(d) in carve_out && continue
            has_time_series(d, SingleTimeSeries, "max_active_power") || continue
            peak = maximum(_mw(d, "max_active_power"))
            peak <= get_max_active_power(d, u"MW") * (1 + 1e-6) || push!(over, get_name(d))
        end
        @test isempty(over)
    end
end

@testset "RTS scenario builders resize renewables together with their output" begin
    # A resized plant keeps its capacity factor: peak output over maximum matches the same
    # plant in plain RTS (the two-RTO twin is named `<plant>_twin`).
    peak_ratio(d) = maximum(_mw(d, "max_active_power")) / get_max_active_power(d, u"MW")
    plain = Dict(
        get_name(d) => peak_ratio(d) for
        d in get_components(RenewableGen, _build_rts("RTS_GMLC_DA_sys_noForecast")) if
        has_time_series(d, SingleTimeSeries, "max_active_power")
    )
    for name in ("modified_RTS_GMLC_DA_sys_noForecast", "AC_TWO_RTO_RTS_1Hr_sys")
        changed = String[]
        n = 0
        for d in get_components(RenewableGen, _build_rts(name))
            key = replace(get_name(d), r"_twin$" => "")
            haskey(plain, key) || continue
            n += 1
            isapprox(peak_ratio(d), plain[key]; rtol = 1e-6) || push!(changed, get_name(d))
        end
        @test n > 0
        @test isempty(changed)
    end
end

@testset "RTS hydro series and zone loads match the source CSVs" begin
    for (name, resolution_s) in (("RTS_GMLC_DA_sys", 3600), ("RTS_GMLC_RT_sys", 300))
        sys = _build_rts(name)
        pointers = _pointers(resolution_s)

        # Hydro output and reservoir inflow are the CSV columns in MW.
        hydro = filter(p -> occursin("/Hydro/", p["data_file"]), pointers)
        @test !isempty(hydro)
        for p in hydro
            @test _matches(_mw(_series_owner(sys, p), p["name"]), _csv_column(p))
        end

        # Each zone's loads read back as their `MW Load` share of the zone's series.
        zones = filter(p -> p["category"] == "Area", pointers)
        @test !isempty(zones)
        for p in zones
            area = get_component(Area, sys, p["component_name"])
            loads = collect(get_components_in_aggregation_topology(PowerLoad, sys, area))
            total = sum(get_max_active_power(l, u"MW") for l in loads)
            zone = _csv_column(p)
            for l in loads
                share = get_max_active_power(l, u"MW") / total
                @test _matches(_mw(l, "max_active_power"), zone .* share)
            end
        end
    end
end
