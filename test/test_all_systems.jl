@testset "all_systems" begin
    # Test with a minimal catalog containing just one system
    category = MatpowerTestSystems
    name = first(list_systems(category))
    sys = build_system(category, name)
    @test sys isa PSY.System

    # Test that all_systems returns a dict with the expected type
    small_descriptor = PSB.SYSTEM_CATALOG[findfirst(
        d -> PSB.get_category(d) == category && PSB.get_name(d) == name,
        PSB.SYSTEM_CATALOG,
    )]
    small_catalog = SystemCatalog([small_descriptor])
    result = all_systems(; system_catalog = small_catalog)
    @test result isa Dict{Tuple{DataType, String}, PSY.System}
    @test length(result) == 1
    @test haskey(result, (category, name))
    @test result[(category, name)] isa PSY.System
end
