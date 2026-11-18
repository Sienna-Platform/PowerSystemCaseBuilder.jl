@testset "5-bus pointer data states every series in natural units" begin
    catalog = SystemCatalog(SYSTEM_CATALOG)
    for name in (
        "5_bus_hydro_uc_sys",
        "5_bus_hydro_uc_sys_with_targets",
        "5_bus_hydro_ed_sys",
        "5_bus_hydro_ed_sys_with_targets",
        "5_bus_hydro_wk_sys",
        "5_bus_hydro_wk_sys_with_targets",
        "5_bus_matpower_DA",
        "5_bus_matpower_RT",
        "5_bus_matpower_AGC",
    )
        descriptor = PSB.get_system_descriptor(PSISystems, catalog, name)
        sys = PSB.get_build_function(descriptor)(;
            raw_data = PSB.get_raw_data(descriptor),
            PSB.get_default_arguments(descriptor)...,
        )
        n_series = 0
        for c in get_components(has_time_series, Component, sys),
            md in PSY.IS.list_time_series_metadata(c)

            n_series += 1
            @test !isnothing(PSY.IS.get_units(md))
            @test !isnothing(PSY.IS.get_quantity_kind(md))
            @test isnothing(PSY.IS.get_per_unit_of(md))
        end
        @test n_series > 0
    end
end
