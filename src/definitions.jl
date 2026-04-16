const PACKAGE_DIR = joinpath(dirname(dirname(pathof(PowerSystemCaseBuilder))))
const DATA_DIR = joinpath(LazyArtifacts.artifact"CaseData", "PowerSystemsTestData-4.0.2")

const RTS_DIR = joinpath(LazyArtifacts.artifact"rts", "RTS-GMLC-0.2.3")

const SYSTEM_DESCRIPTORS_FILE = joinpath(PACKAGE_DIR, "src", "system_descriptor.jl")

const SERIALIZED_DIR = joinpath(PACKAGE_DIR, "data", "serialized_system")

const SERIALIZE_FILE_EXTENSIONS =
    [".json", "_metadata.json", "_validation_descriptors.json", "_time_series_storage.h5"]

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

const PSSE_PARSER_TAP_RATIO_LBOUND = 0.5
