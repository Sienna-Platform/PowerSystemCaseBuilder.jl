# Select and Load a Power System

```@setup pscb
using PowerSystemCaseBuilder
```

`PowerSystemCaseBuilder.jl` offers a catalog of power system test data, already formatted
and available to load as [`PowerSystems.System`](@extref) objects.

## Select

View the available categories of power systems in the catalog using
[`show_categories`](@ref):

```@example pscb
show_categories()
```

Choose a category, or explore the [`SystemCategory`](@ref) documentation
to learn about each category.

Use [`show_systems`](@ref) to see the name and description of the available
[`PowerSystems.System`](@extref)s in the selected category, e.g, [`PSISystems`](@ref):

```@example pscb
show_systems(PSISystems)
```

## Build

Finally, use [`build_system`](@ref) to load your selected system:

```@example pscb
sys = build_system(PSISystems, "5_bus_hydro_ed_sys")
```

## Next Steps

Refer to the [`PowerSystems.jl`](https://sienna-platform.github.io/PowerSystems.jl/stable/)
documentation for how to modify the test system or build your own, and the
[`PowerSimulations.jl`](https://sienna-platform.github.io/PowerSimulations.jl/stable/) and
[`PowerSimulationsDynamics.jl`](https://sienna-platform.github.io/PowerSimulationsDynamics.jl/stable/)
documentation for how to set up and run simulations.
