@testset "Test time series bases are normalized without changing their scaling" begin
    catalog = SystemCatalog(SYSTEM_CATALOG)
    n_reserves = 0
    # 5_bus_hydro_uc_sys's reserve series back forecast views, which must be derived again.
    for (category, name) in (
        (PSITestSystems, "c_sys5_uc"),
        (PSISystems, "5_bus_hydro_uc_sys"),
        (PSISystems, "5_bus_matpower_DA"),
    )
        descriptor = PSB.get_system_descriptor(category, catalog, name)
        raw = PSB.get_build_function(descriptor)(;
            raw_data = PSB.get_raw_data(descriptor),
            PSB.filter_descriptor_kwargs(descriptor)...,
        )
        sys = build_system(category, name; force_build = true, skip_serialization = true)

        for c in get_components(PSB._rebase_to_max_active_power, StaticInjection, raw)
            normalized = get_component(typeof(c), sys, get_name(c))
            @test get_max_active_power(normalized, CU) ≈ 1.0
            @test get_max_active_power(normalized, SU) ≈ get_max_active_power(c, SU)
        end

        for r in get_components(PSB._fold_requirement, PSY.AbstractReserve, raw)
            n_reserves += 1
            normalized = get_component(typeof(r), sys, get_name(r))
            @test get_requirement(normalized, SU) == 1.0
            before = get_time_series_values(SingleTimeSeries, r, "requirement")
            after = get_time_series_values(SingleTimeSeries, normalized, "requirement")
            @test after ≈ before .* get_requirement(r, SU)
            # Forecast views over the replaced series are derived again.
            @test length(PSY.IS.list_time_series_metadata(normalized)) ==
                  length(PSY.IS.list_time_series_metadata(r))
        end
    end
    @test n_reserves > 0
end
