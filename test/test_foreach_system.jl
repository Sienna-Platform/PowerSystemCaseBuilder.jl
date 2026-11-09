@testset "foreach_system" begin
    category = MatpowerTestSystems
    name = first(list_systems(category))
    good = PSB.get_system_descriptor(category, SystemCatalog(), name)
    # Supports :add_forecasts, so passing it must not drop `good`, which doesn't.
    bad = SystemDescriptor(;
        name = "always_fails",
        description = "build_function always throws",
        category = category,
        build_function = (; kwargs...) -> throw(ArgumentError("boom")),
        supported_arguments = [
            PSB.SystemArgument(;
                name = :add_forecasts,
                allowed_values = Set([true, false]),
            ),
        ],
    )
    catalog = SystemCatalog([good, bad])

    seen = Dict{Tuple{DataType, String}, PSY.System}()
    @test_logs (:warn, r"Skipping system .*always_fails") match_mode = :any foreach_system(;
        system_catalog = catalog,
        add_forecasts = false,
    ) do c, n, sys
        seen[(c, n)] = sys
    end
    @test collect(keys(seen)) == [(category, name)]
    @test !haskey(seen, (category, "always_fails"))

    @test_throws ErrorException foreach_system((c, n, s) -> nothing;
        system_catalog = catalog, not_an_arg = 1)
end
