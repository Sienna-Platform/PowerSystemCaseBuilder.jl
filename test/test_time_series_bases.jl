# Hand-made data that states its devices on their own base.
const _OWN_BASE_DATA =
    ("data_5bus_pu.jl", "data_14bus_pu.jl", "data_10bus_ac_dc_pu.jl", "data_118bus.jl")

@testset "Hand-made data needs no normalization" begin
    catalog = SystemCatalog(SYSTEM_CATALOG)
    n_systems = 0
    for category in PSB.list_categories(catalog),
        descriptor in PSB.get_system_descriptors(category, catalog)

        raw_data = PSB.get_raw_data(descriptor)
        raw_data isa AbstractString && any(f -> endswith(raw_data, f), _OWN_BASE_DATA) ||
            continue
        sys = PSB.get_build_function(descriptor)(;
            raw_data = raw_data,
            PSB.get_default_arguments(descriptor)...,
        )
        n_systems += 1
        @test isempty(
            get_components(PSB._rebase_to_max_active_power, StaticInjection, sys),
        )
    end
    @test n_systems > 0
end

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
