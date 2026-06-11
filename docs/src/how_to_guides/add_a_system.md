# Add a `System` to the Catalog

This page guides developers in how to add new [`PowerSystems.System`](@extref)s to the
`PowerSystemCaseBuilder.jl` [`SystemCatalog`](@ref). If you are a user rather than a
developer, please refer to how to [Select and Load a Power System](@ref) instead.

## Defining `System` Data and Adding It To The Catalog

Adding a new [`PowerSystems.System`](@extref) to `PowerSystemCaseBuilder.jl` requires
coordinated changes to two repositories: the system is defined and described through custom
functions in `PowerSystemCaseBuilder.jl`, while the underlying data is hosted in the
[`PowerSystemsTestData`](https://github.com/Sienna-Platform/PowerSystemsTestData) repository.

The steps to complete these changes are:

 1. Create a new folder in the
    [`PowerSystemsTestData`](https://github.com/Sienna-Platform/PowerSystemsTestData)
    repository and add the `System`'s input data files, such as `.csv`, `.raw`, `.dyr`,
    `.m`, and/or `.jl` files

 2. Define a custom `build_*` function that loads or compiles your `System` in the appropriate file
    in `PowerSystemCaseBuilder.jl`'s
    [`src/library/`](https://github.com/Sienna-Platform/PowerSystemCaseBuilder.jl/tree/main/src/library)
    directory. The files are organized according to [`SystemCategory`](@ref).
    See the
    [existing files in `src/library/`](https://github.com/Sienna-Platform/PowerSystemCaseBuilder.jl/tree/main/src/library)
    for examples.
 3. Define a new [`SystemDescriptor`](@ref) in
    [`src/system_descriptor_data.jl`](https://github.com/Sienna-Platform/PowerSystemCaseBuilder.jl/blob/main/src/system_descriptor_data.jl),
    with:
    
      + The `build_function` argument pointing to your new `build_*` function
      + The `raw_data` argument pointing to either the directory you added in
        [`PowerSystemsTestData`](https://github.com/Sienna-Platform/PowerSystemsTestData), or a
        `.jl`, `.raw`, or `.m` file within it. See the existing systems for examples.

## Testing the New `System` Locally

Before opening pull requests for both `PowerSystemCaseBuilder.jl` and `PowerSystemsTestData`,
ensure that your new `System` builds correctly by testing it locally:

 1. Change the `DATA_DIR` definition in `PowerSystemCaseBuilder.jl`'s
    [`src/definitions.jl`](https://github.com/Sienna-Platform/PowerSystemCaseBuilder.jl/blob/main/src/definitions.jl#L2)
    to point to your local fork/clone of `PowerSystemsTestData`
 2. In a new Julia REPL, [`Pkg.develop`](@extref) `PowerSystemCaseBuilder.jl`, pointing to
    your local fork/clone
 3. Try using [`build_system`](@ref) on your new `System` and check for errors and accuracy
 4. Finally, revert changes to the `DATA_DIR` definition before submitting pull requests
