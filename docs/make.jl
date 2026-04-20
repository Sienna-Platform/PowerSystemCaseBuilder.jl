using Documenter, PowerSystemCaseBuilder
import DataStructures: OrderedDict
# using Literate
using DocumenterInterLinks

links = InterLinks(
    "PowerSystems" => "https://sienna-platform.github.io/PowerSystems.jl/stable/",
    "Pkg" => "https://pkgdocs.julialang.org/v1/",
)

if isfile("docs/src/howto/.DS_Store.md")
    rm("docs/src/howto/.DS_Store.md")
end

include(joinpath(@__DIR__, "src", "reference", "make_catalog_reference.jl"))
catalog_md_path = joinpath(@__DIR__, "src", "reference", "generated_catalog.md")
write(catalog_md_path, generate_catalog_md())

pages = OrderedDict(
    "Welcome" => "index.md",
    ## TODO follow this diataxis structure as new material is added
    # "Tutorials" => Any["stub" => "tutorials/stub.md"],
    "How to..." => Any["Select and Load a Power System" => "how_to_guides/explore_load.md",
        "Add a `System` to the Catalog" => "how_to_guides/add_a_system.md",],
    # "Explanation" => Any["stub" => "explanation/stub.md"],
    "Reference" => Any[
        "Public API" => "reference/public.md",
        "Full Catalog of `System`s" => "reference/generated_catalog.md",
        "Developers" => ["Developer Guidelines" => "reference/developer_guidelines.md",
        "Internals" => "reference/internal.md"],
    ],
)

makedocs(;
    sitename = "PowerSystemCaseBuilder.jl",
    format = Documenter.HTML(;
        mathengine = Documenter.MathJax(),
        prettyurls = haskey(ENV, "GITHUB_ACTIONS"),
    ),
    modules = [PowerSystemCaseBuilder],
    authors = "Sourabh Dalvi, Kate Doubleday",
    pages = Any[p for p in pages],
    plugins = [links],
)

deploydocs(;
    repo = "github.com/Sienna-Platform/PowerSystemCaseBuilder.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "main",
    devurl = "dev",
    push_preview=true,
    versions = ["stable" => "v^", "v#.#"],
)
