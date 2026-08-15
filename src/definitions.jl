const PACKAGE_DIR = joinpath(dirname(dirname(pathof(PowerSystemCaseBuilder))))
const DATA_DIR = joinpath(LazyArtifacts.artifact"CaseData", "PowerSystemsTestData-5.0-dev4")

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
