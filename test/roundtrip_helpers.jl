# Fixtures that carry corrupt data which the parser should report at error level.
const EXPECTED_BUILD_LOG_ERRORS = Dict(
    "isolated_bus_test_system" => r"topologically isolated bus",
)

# Field-by-field System comparison for write/read round trips.
# Components compare by (type, name) per field when reached through a reference; every
# component is also walked in full once, from the system's component list.

_SKIPPED_FIELDS = (:internal,)

_diff!(out, path, a::PSY.Component, b::PSY.Component) = _diff_reference!(out, path, a, b)
_diff!(out, path, a::AbstractString, b::AbstractString) = _diff_equal!(out, path, a, b)
_diff!(out, path, a::Symbol, b::Symbol) = _diff_equal!(out, path, a, b)
_diff!(out, path, a::Number, b::Number) = _diff_number!(out, path, a, b)
_diff!(out, path, a::Enum, b::Enum) = _diff_equal!(out, path, a, b)
_diff!(out, path, a::Nothing, b::Nothing) = nothing
_diff!(out, path, a::Union{Tuple, NamedTuple}, b::Union{Tuple, NamedTuple}) =
    _diff_sequence!(out, path, collect(pairs(a)), collect(pairs(b)))
_diff!(out, path, a::AbstractArray, b::AbstractArray) = _diff_array!(out, path, a, b)
_diff!(out, path, a::AbstractDict, b::AbstractDict) = _diff_dict!(out, path, a, b)
_diff!(out, path, a::Base.UUID, b::Base.UUID) = nothing

function _diff!(out, path, a, b)
    if typeof(a) != typeof(b)
        push!(out, "$path: type $(typeof(a)) vs $(typeof(b))")
    elseif fieldcount(typeof(a)) == 0
        _diff_equal!(out, path, a, b)
    else
        _diff_fields!(out, path, a, b)
    end
    return
end

function _diff_equal!(out, path, a, b)
    if !isequal(a, b)
        push!(out, "$path: $(repr(a)) vs $(repr(b))")
    end
    return
end

# Same-type numbers must be bit-identical; CU round trips convert nothing.
function _diff_number!(out, path, a, b)
    if typeof(a) != typeof(b)
        push!(out, "$path: type $(typeof(a)) vs $(typeof(b)) ($a vs $b)")
    elseif !isequal(a, b)
        push!(out, "$path: $a vs $b")
    end
    return
end

function _diff_reference!(out, path, a, b)
    if typeof(a) != typeof(b) || PSY.get_name(a) != PSY.get_name(b)
        push!(
            out,
            "$path: reference $(typeof(a))/$(PSY.get_name(a)) vs $(typeof(b))/$(PSY.get_name(b))",
        )
    end
    return
end

function _diff_array!(out, path, a, b)
    if size(a) != size(b)
        push!(out, "$path: size $(size(a)) vs $(size(b))")
        return
    end
    for i in eachindex(a)
        _diff!(out, "$path[$i]", a[i], b[i])
    end
    return
end

function _diff_sequence!(out, path, a, b)
    if length(a) != length(b)
        push!(out, "$path: length $(length(a)) vs $(length(b))")
        return
    end
    for ((ka, va), (_, vb)) in zip(a, b)
        _diff!(out, "$path.$ka", va, vb)
    end
    return
end

function _diff_dict!(out, path, a, b)
    if Set(keys(a)) != Set(keys(b))
        push!(
            out,
            "$path: keys $(sort!(collect(string.(keys(a))))) vs $(sort!(collect(string.(keys(b)))))",
        )
        return
    end
    for k in keys(a)
        _diff!(out, "$path[$(repr(k))]", a[k], b[k])
    end
    return
end

function _diff_fields!(out, path, a, b)
    for f in fieldnames(typeof(a))
        if f in _SKIPPED_FIELDS
            continue
        end
        _diff!(out, "$path.$f", getfield(a, f), getfield(b, f))
    end
    return
end

function _component_index(sys::PSY.System)
    index = Dict{Tuple{DataType, String}, Any}()
    for c in PSY.get_components(PSY.Component, sys)
        key = (typeof(c), PSY.get_name(c))
        if haskey(index, key)
            error("duplicate component $(key[1])/$(key[2]) in one system")
        end
        index[key] = c
    end
    return index
end

"""
Return a vector of difference strings between two systems: every field of every component,
including nested dynamic function blocks. Empty means identical.
"""
function compare_systems(sys1::PSY.System, sys2::PSY.System)
    out = String[]
    i1 = _component_index(sys1)
    i2 = _component_index(sys2)
    for key in setdiff(keys(i1), keys(i2))
        push!(out, "missing after read: $(key[1])/$(key[2])")
    end
    for key in setdiff(keys(i2), keys(i1))
        push!(out, "extra after read: $(key[1])/$(key[2])")
    end
    for key in intersect(keys(i1), keys(i2))
        _diff_fields!(out, "$(key[1])/$(key[2])", i1[key], i2[key])
    end
    _diff_equal!(out, "System.frequency", PSY.get_frequency(sys1), PSY.get_frequency(sys2))
    _diff_equal!(
        out,
        "System.base_power",
        PSY.get_base_power(sys1),
        PSY.get_base_power(sys2),
    )
    return sort!(out)
end

"""Write `sys` as a PSY document bundle, read it back, and return the read system."""
function roundtrip_system(sys::PSY.System)
    return mktempdir() do dir
        bundle = joinpath(dir, "bundle")
        PSY.to_file(sys, bundle)
        return PSY.from_file(bundle)
    end
end

count_dynamic_injectors(sys::PSY.System) =
    length(collect(PSY.get_components(PSY.DynamicInjection, sys)))
