const PACKAGE_DIR = joinpath(dirname(dirname(pathof(PowerSystemCaseBuilder))))
# GitHub's tag tarball unpacks to a single "<repo>-<tag>" directory; read it back rather
# than hardcode the tag, so a re-tag needs no code change here.
const _CASE_DATA_ARTIFACT_DIR = LazyArtifacts.artifact"CaseData"
const DATA_DIR = joinpath(_CASE_DATA_ARTIFACT_DIR, only(readdir(_CASE_DATA_ARTIFACT_DIR)))

const RTS_DIR = joinpath(LazyArtifacts.artifact"rts", "RTS-GMLC-0.2.3")

const SYSTEM_DESCRIPTORS_FILE = joinpath(PACKAGE_DIR, "src", "system_descriptor.jl")

const SERIALIZED_DIR = joinpath(PACKAGE_DIR, "data", "serialized_system")

"""
Column-to-field map for the RTS-GMLC tables, shipped here rather than read from the RTS
artifact.

The artifact's own `user_descriptors.yaml` declares neither the emission columns, the MTTF/MTTR
and outage-rate columns, the bus shunt columns, the LTE/STE emergency ratings, nor lat/lng — so
`PowerTableDataParser`'s emissions, outage, and geographic parsers found `nothing`, skipped, and
that data reached the `System` nowhere. It survived only as unmapped extras on the document,
which PowerSystems does not read back.

This copy (from `PowerTableDataParser.jl/test/descriptors/rts_user_descriptors.yaml`, the
descriptor its own acceptance tests use) declares them, so the parsers build the attributes the
tables describe.
"""
const RTS_USER_DESCRIPTOR_FILE =
    joinpath(PACKAGE_DIR, "descriptors", "rts_user_descriptors.yaml")

const ACCEPTED_PSID_TEST_SYSTEMS_KWARGS = [:avr_type, :tg_type, :pss_type, :gen_type]
const AVAILABLE_PSID_PSSE_AVRS_TEST =
    ["AC1A", "AC1A_SAT", "EXAC1", "EXST1", "SEXS", "SEXS_noTE"]

const AVAILABLE_PSID_PSSE_TGS_TEST = ["GAST", "HYGOV", "TGOV1"]

const AVAILABLE_PSID_PSSE_GENS_TEST = [
    "GENCLS",
    "GENROE",
    "GENROE_SAT",
    "GENROU",
    "GENROU_NoSAT",
    "GENROU_SAT",
    "GENSAE",
    "GENSAL",
]

const AVAILABLE_PSID_PSSE_PSS_TEST = ["STAB1", "IEEEST", "IEEEST_FILTER"]

const INFINITE_BOUND = 1e6

const PSSE_PARSER_TAP_RATIO_UBOUND = 1.5
const PSSE_PARSER_TAP_RATIO_LBOUND = 0.5

# Keyed by WindingCategory enum for PSY component assembly in power_models_data.jl.
# PowerFlowFileParser has its own integer-keyed WINDING_NAMES for raw-data parsing.
const WINDING_NAMES = Dict(
    WindingCategory.PRIMARY_WINDING => "primary",
    WindingCategory.SECONDARY_WINDING => "secondary",
    WindingCategory.TERTIARY_WINDING => "tertiary",
)

"""
Keyword arguments declaring a time series stored per unit on its owner's own base.

Replaces `scaling_factor_multiplier`, which InfrastructureSystems removed. A normalized
profile used to be stored bare next to the name of an accessor, and every read multiplied it
by that accessor's value on the owner. The profile is still stored the same way — one shared
array many components can point at — but the storage now *declares* what it is:
`unit_system` says the values are per unit on the component's own base, and `quantity_kind`
names the physical quantity they scale to. That carries the same meaning without a function
name for the reader to resolve, and leaves the scaling to the consumer.

`units` stays `nothing`: a per-unit basis is not a units label.
"""
per_unit_of(quantity_kind::AbstractString) =
    (unit_system = IS.DU, units = nothing, quantity_kind = quantity_kind)

"""
The quantity a profile normalized against a reservoir's storage capacity scales to.

Depends on the reservoir: `level_data_type` decides whether its levels are accounted in
energy, in volume, or as a head. `PowerTableDataParser` owns the mapping so the fixtures and
the table parser cannot drift apart on what a reservoir-normalized series means.
"""
reservoir_level_quantity(reservoir::PSY.HydroReservoir) =
    PowerTableDataParser.quantity_kind_for_multiplier(
        "get_storage_capacity",
        () -> string(PSY.get_level_data_type(reservoir)),
    )

"""
An `EnergyReservoirStorage` has no `level_data_type` to choose from: its `storage_capacity`
is canonically MWh, with `conversion_factor` scaling a non-MWh medium into it. So its levels
are energy however the medium is measured.
"""
reservoir_level_quantity(::PSY.EnergyReservoirStorage) = "energy"
