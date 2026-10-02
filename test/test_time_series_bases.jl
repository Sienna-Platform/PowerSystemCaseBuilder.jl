@testset "Test time series bases are normalized without changing their scaling" begin
    catalog = SystemCatalog(SYSTEM_CATALOG)
    series_values(c, md) =
        get_time_series_values(c, get_time_series(c, PSY.IS.get_time_series_key(md)))
    n_reserves = 0
    for (category, name, kwargs) in (
        (PSITestSystems, "c_sys5_uc", (add_reserves = true,)),
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

        # Reserves still scale their series by `requirement`, so they're left alone.
        for r in get_components(has_time_series, PSY.AbstractReserve, raw)
            n_reserves += 1
            normalized = get_component(typeof(r), sys, get_name(r))
            @test get_requirement(normalized, SU) == get_requirement(r, SU)
            for md in PSY.IS.list_time_series_metadata(r)
                @test series_values(normalized, md) == series_values(r, md)
            end
        end
    end
    @test n_reserves > 0
end
