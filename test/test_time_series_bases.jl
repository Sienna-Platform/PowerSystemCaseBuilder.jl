@testset "Test time series bases are normalized without changing their scaling" begin
    catalog = SystemCatalog(SYSTEM_CATALOG)
    series_values(c, md) =
        get_time_series_values(c, get_time_series(c, PSY.IS.get_time_series_key(md)))
    n_reserves = 0
    for (category, name, kwargs) in (
        # Reserves with Deterministic forecasts.
        (PSITestSystems, "c_sys5_uc", (add_reserves = true,)),
        # Reserve series that back forecast views, which must be derived again.
        (PSISystems, "5_bus_hydro_uc_sys", (;)),
        (PSISystems, "5_bus_matpower_DA", (;)),
    )
        descriptor = PSB.get_system_descriptor(category, catalog, name)
        raw = PSB.get_build_function(descriptor)(;
            raw_data = PSB.get_raw_data(descriptor),
            PSB.filter_descriptor_kwargs(descriptor; kwargs...)...,
        )
        sys = build_system(
            category, name; force_build = true, skip_serialization = true, kwargs...)

        for c in get_components(PSB._rebase_to_max_active_power, StaticInjection, raw)
            normalized = get_component(typeof(c), sys, get_name(c))
            @test get_max_active_power(normalized, CU) ≈ 1.0
            @test get_max_active_power(normalized, SU) ≈ get_max_active_power(c, SU)
        end

        for r in get_components(PSB._fold_requirement, PSY.AbstractReserve, raw)
            n_reserves += 1
            normalized = get_component(typeof(r), sys, get_name(r))
            @test get_requirement(normalized, SU) == 1.0
            mds = PSY.IS.list_time_series_metadata(r)
            # Forecast views over the replaced series are derived again.
            @test length(PSY.IS.list_time_series_metadata(normalized)) == length(mds)
            for md in mds
                T = typeof(md).parameters[1]
                T <: DeterministicSingleTimeSeries && continue
                md1 = only(
                    PSY.IS.list_time_series_metadata(
                        normalized; time_series_type = T, name = PSY.IS.get_name(md)),
                )
                @test series_values(normalized, md1) ≈
                      series_values(r, md) .* get_requirement(r, SU)
            end
        end
    end
    @test n_reserves > 0
end
