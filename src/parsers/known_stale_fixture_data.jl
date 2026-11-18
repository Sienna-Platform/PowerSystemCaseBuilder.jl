"""
Matpower fixture data that no Sienna type represents, and that PowerFlowFileParser's
OpenAPI builder therefore rejects rather than skips. Matched exactly so any new data of
either kind still errors.

`ne_branch` (case3_tnep.m, case5_tnep.m): PowerModels' transmission-expansion candidate
branches.

`313_STORAGE_1` (RTS_GMLC.m, gen row 158): a storage unit listed as a generator. Matpower
storage belongs in its own `storage` table, which this case does not have.
"""
const KNOWN_UNREAD_MATPOWER_SECTIONS = ("ne_branch",)
const KNOWN_STORAGE_GENERATOR_ROWS = Set(["313_STORAGE_1"])

function drop_known_unread_matpower_data!(pm_data::PowerFlowFileParser.PowerModelsData)
    data = pm_data.data
    for section in KNOWN_UNREAD_MATPOWER_SECTIONS
        delete!(data, section)
    end
    filter!(p -> get(last(p), "name", nothing) ∉ KNOWN_STORAGE_GENERATOR_ROWS, data["gen"])
    return pm_data
end
