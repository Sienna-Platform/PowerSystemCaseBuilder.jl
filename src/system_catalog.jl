"""
A container for a catalog of [`PowerSystems.System`](@extref) data sets

# Example
```julia
SystemCatalog()
```
Returns the `PowerSystemCaseBuilder.jl` catalog
"""
mutable struct SystemCatalog
    data::Dict{DataType, Dict{String, SystemDescriptor}}
end

function get_system_descriptor(
    category::Type{<:SystemCategory},
    catalog::SystemCatalog,
    name::String,
)
    data = catalog.data
    if haskey(data, category) && haskey(data[category], name)
        return data[category][name]
    else
        error("System $(name) of Category $(category) not found in current SystemCatalog")
    end
end

function get_system_descriptors(category::Type{<:SystemCategory}, catalog::SystemCatalog)
    data = catalog.data
    if haskey(data, category)
        array = SystemDescriptor[descriptor for descriptor in values(data[category])]
        return array
    else
        error("Category $(category) not found in SystemCatalog")
    end
end

"""
Returns a vector of [`SystemCategory`](@ref)s available in the `PowerSystemCaseBuilder.jl`
[`SystemCatalog`](@ref)
"""
function list_categories()
    catalog = SystemCatalog()
    return list_categories(catalog)
end

list_categories(c::SystemCatalog) = sort!([x for x in (keys(c.data))]; by = x -> string(x))

"""
Returns a vector of names of the systems available in one [`SystemCategory`](@ref) in the
`PowerSystemCaseBuilder.jl` [`SystemCatalog`](@ref)
"""
function list_systems(category::Type{<:SystemCategory})
    catalog = SystemCatalog()
    return list_systems(catalog, category)
end

function list_systems(catalog::SystemCatalog, category::Type{<:SystemCategory})
    data = catalog.data
    if haskey(data, category)
        return sort!(collect(keys(data[category])); by = x -> string(x))
    else
        error("Category $(category) not found in SystemCatalog")
        return [] # for type stability reasons
    end
end

"""
Builds each [`PowerSystems.System`](@extref) in the [`SystemCatalog`](@ref) one at a time
and calls `f(category, name, sys)` on it, so only one `System` is held in memory at once.

Each system receives only the keyword arguments it supports (plus `System` and build
keywords); a keyword supported by no system in the catalog is an error. Systems that fail to
build are skipped with a warning.

# Example
```julia
sizes = Dict{Tuple{DataType, String}, Int}()
foreach_system() do category, name, sys
    sizes[(category, name)] = length(PSY.get_components(PSY.ACBus, sys))
end
```

# Accepted Key Words
- `system_catalog::SystemCatalog`: Defaults to the `PowerSystemCaseBuilder.jl` catalog of
  `System`s
- All other keyword arguments are forwarded to [`build_system`](@ref)
"""
function foreach_system(
    f::Function;
    system_catalog::SystemCatalog = SystemCatalog(),
    kwargs...,
)
    descriptors = [d for cat in values(system_catalog.data) for d in values(cat)]
    always =
        union(PSY.SYSTEM_KWARGS, (:force_build, :assign_new_uuids, :skip_serialization))
    supported = union(always, get_supported_argument_names.(descriptors)...)
    unknown = setdiff(keys(kwargs), supported)
    isempty(unknown) ||
        error("No system in the catalog supports these keyword arguments: $unknown")
    for d in descriptors
        category, name = get_category(d), get_name(d)
        names = union(always, get_supported_argument_names(d))
        sys = try
            build_system(
                category,
                name;
                system_catalog,
                filter(p -> first(p) in names, kwargs)...,
            )
        catch e
            e isa InterruptException && rethrow()
            @warn "Skipping system $(category)/$(name)" exception =
                (e, catch_backtrace())
            continue
        end
        f(category, name, sys)
    end
    return
end

function SystemCatalog(system_catalogue::Array{SystemDescriptor} = SYSTEM_CATALOG)
    data = Dict{DataType, Dict{String, SystemDescriptor}}()
    unique_names = Set{String}()
    for descriptor in system_catalogue
        category = get_category(descriptor)
        if descriptor.name in unique_names
            error("a duplicate name is detected: $(descriptor.name)")
        end
        push!(unique_names, descriptor.name)
        if haskey(data, category)
            push!(data[category], (descriptor.name => descriptor))
        else
            push!(data, (category => Dict{String, SystemDescriptor}()))
            push!(data[category], (descriptor.name => descriptor))
        end
    end
    return SystemCatalog(data)
end
