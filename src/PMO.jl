module PMO

using DataStructures
using JSON
using JuliaDB, HTTP
using UUIDs
using LinearAlgebra, SparseArrays

include("model.jl")
include("readers.jl")
include("writers.jl")
include("register.jl")

const PMO_GIT_DATA_URL     = "https://github.com/PolynomialMomentOptimization/data"
const PMO_GIT_REGISTRY_URL = "https://github.com/PolynomialMomentOptimization/registries"
const PMO_RAW_DATA_URL     = "https://raw.githubusercontent.com/PolynomialMomentOptimization/data/master"
const PMO_LOCAL_DATA_DIR  = joinpath(homedir(), ".julia", "PMO/data")
const PMO_LOCAL_REGISTRY_DIR = joinpath(homedir(), ".julia", "PMO/registries")

end 
