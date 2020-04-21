module POP

using DataStructures
using JSON
using JuliaDB
using HTTP
using UUIDs


include("popmodel.jl")
include("readers.jl")
include("writers.jl")
include("register.jl")

const GIT_DATA_URL     = "https://github.com/PolynomialOptimization/data"
const GIT_REGISTRY_URL = "https://github.com/PolynomialOptimization/registries"
const RAW_DATA_URL     = "https://raw.githubusercontent.com/PolynomialOptimization/data/master"
const LOCAL_DATA_DIR  = joinpath(homedir(), ".julia", "POP/data")
const LOCAL_REGISTRY_DIR = joinpath(homedir(), ".julia", "POP/registries")

end 
