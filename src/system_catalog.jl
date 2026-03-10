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
Builds all [`PowerSystems.System`](@extref)s in the [`SystemCatalog`](@ref) and returns them
as a `Dict` keyed by `(category, system_name)` tuples.

Systems that require additional keyword arguments are built with their default arguments
where available. Systems that fail to build are skipped with a warning.

# Accepted Key Words
- `system_catalog::SystemCatalog`: Defaults to the `PowerSystemCaseBuilder.jl` catalog of
  `System`s
- All other keyword arguments are forwarded to [`build_system`](@ref)
"""
function all_systems(;
    system_catalog::SystemCatalog = SystemCatalog(),
    kwargs...,
)
    result = Dict{Tuple{DataType, String}, PSY.System}()
    for category in list_categories(system_catalog)
        for name in list_systems(system_catalog, category)
            try
                result[(category, name)] = build_system(
                    category, name; system_catalog = system_catalog, kwargs...,
                )
            catch e
                @warn "Skipping system $(category)/$(name)" exception =
                    (e, catch_backtrace())
            end
        end
    end
    return result
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
