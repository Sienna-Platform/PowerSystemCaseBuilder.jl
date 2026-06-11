# PowerSystemCaseBuilder.jl

```@meta
CurrentModule = PowerSystemCaseBuilder
```

## Overview

`PowerSystemCaseBuilder.jl` is a [`Julia`](http://www.julialang.org) package that provides a library
of power systems test cases using the
[`PowerSystems.jl`](https://sienna-platform.github.io/PowerSystems.jl/stable/) data model:
[`PowerSystems.System`](@extref).

`PowerSystemCaseBuilder.jl` is a simple tool to build power systems ranging from
5-Bus systems to entire grid systems for the purpose of testing or prototyping power system
models. This package facilitates the open sharing of data sets for power systems
modeling.

The main features include:

  - Comprehensive and extensible library of power systems for modeling.
  - Automated serialization/de-serialization of cataloged [`PowerSystems.System`](@extref)s.

`PowerSystemCaseBuilder.jl` is an active project under development, and we welcome your feedback,
suggestions, and bug reports.

## About Sienna

`PowerSystemCaseBuilder.jl` is part of the National Laboratory of the Rockies (formerly known as NREL)'s
[Sienna ecosystem](https://sienna-platform.github.io/Sienna/), an open source framework for
power system modeling, simulation, and optimization. The Sienna ecosystem can be
[found on Github](https://github.com/Sienna-Platform/Sienna). It contains three applications:

  - [Sienna\Data](https://sienna-platform.github.io/Sienna/pages/applications/sienna_data.html) enables
    efficient data input, analysis, and transformation
  - [Sienna\Ops](https://sienna-platform.github.io/Sienna/pages/applications/sienna_ops.html) enables
    enables system scheduling simulations by formulating and solving optimization problems
  - [Sienna\Dyn](https://sienna-platform.github.io/Sienna/pages/applications/sienna_dyn.html) enables
    system transient analysis including small signal stability and full system dynamic
    simulations

Each application uses multiple packages in the [`Julia`](http://www.julialang.org)
programming language.

## Installation and Quick Links

  - [Sienna installation page](https://sienna-platform.github.io/Sienna/SiennaDocs/docs/build/how-to/install/):
    Instructions to install `PowerSystemCaseBuilder.jl` and other Sienna\Data packages
  - [Sienna Documentation Hub](https://sienna-platform.github.io/Sienna/SiennaDocs/docs/build/index.html):
    Links to other Sienna packages' documentation
