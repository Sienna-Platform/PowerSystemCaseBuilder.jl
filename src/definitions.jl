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

"""A water reservoir's inflow and outflow: volume flow in m³/s."""
const WATER_FLOW =
    (units = "m^3/s", quantity_kind = "volume_flow_rate")

"""An `ENERGY` reservoir's inflow, outflow and water budget: power in MW."""
const ENERGY_FLOW = (units = "MW", quantity_kind = "active_power")
