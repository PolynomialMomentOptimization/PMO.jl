using DynamicPolynomials
using DataStructures

import Base: setindex!, getindex, show

export pmo, mom, sdp, constraints, objective

"""
 Optimization Problem as an ordered dictionnary.
"""
mutable struct PMOModel 
    model::OrderedDict{String,Any}
end

function PMOModel(F,s) PMOModel(F) end

function Base.setindex!(p::PMOModel, v, k::String)  p.model[k] = v end
function Base.setindex!(p::PMOModel, v, k::Symbol)  p.model[string(k)] = v end
function Base.getindex(p::PMOModel, s::String)  get(p.model, s, "") end
function Base.getindex(p::PMOModel, s::Symbol)  get(p.model, string(s), nothing) end

function Base.show(io::IO,p::PMOModel)
    println(io,"Optimisation model:")
    for (k,v) in p.model
        println(io,"  ",k, " => ",v)
    end
    return io
end

# """
#  Set for the range of the polynomial values
# """
# mutable struct PMOSet
#     val::Any
# end

# function Base.show(io::IO,s::PMOSet)
#     if typeof(s.val)==String
#         print(io,'"',s.val,'"')
#     else
#         print(io,s.val)
#     end
# end

"""
 Polynomial constraint as a polynomial, a set and the variables
"""
mutable struct PolynomialCstr{T}
    cstr::Vector{T}
    var::Any
end

function PolynomialCstr(X) return PolynomialCstr([],X) end

function Base.push!(C::PolynomialCstr, p, s)
    push!(C.cstr, (p,s))
end

#----------------------------------------------------------------------
mutable struct PolynomialObj{T}
    obj::T
    set::String
    var::Any
end

"""
 Moment constraint as a polynomial, a set and the variables
"""
mutable struct MomentCstr{T}
    cstr::Vector{T}
    var::Any
    nu:: Int64
end

function MomentCstr(X,nu::Int64) return MomentCstr([],X,nu) end

function Base.push!(C::MomentCstr, p, s)
    push!(C.cstr, (p,s))
end
    
mutable struct MomentObj{T}
    obj::T
    set::String
    var::Any
end
"""
 Polynomial constraint as a polynomial, a set and the variables
"""
mutable struct SDPCstr{T}
    cstr::Vector{T}
    nvar::Int64
end

function Base.push!(C::SDPCstr, p, s)
    push!(C.cstr, (p,s) )
end

function objective(f, s, X)
    return PolynomialObj(f,s,X)
end
function objective(V::Vector, s, X)
    return MomentObj(V,s,X)
end

"""
Construct a Polynomial Optimization Problem  from

    - P vector of objective function or constraints (p, s) with p a polynomial and s a set
    - X variables of the polynomials.

Example:
--------

    X = @polyvar x y
    model([(x^2*y^2+x*y, "inf"), (x^2+y^2-1,"<=0")], X)
"""
function model(P::Vector, X, type::String)

    F = OrderedDict{String,Any}(
        "type"=> type,
        "variables" => [string(x) for x in X]
    )
    
    F["nvar"] = length(X)
    if type=="polynomial"
        F["constraints"]= PolynomialCstr(X)
    elseif type=="moment" && length(P)>0
        nu = length(P[1][1])
        F["nms"] = nu
        F["constraints"]= MomentCstr(X,nu)
    else
        F["constraints"]= SDPCstr([],0)
    end

    for p in P
        if p[2]=="inf" || p[2] =="sup"
            F["objective"] =  objective(p[1],p[2],X)
        else
            push!(F["constraints"], p[1]*one(Polynomial{true,Int64}),p[2])
        end
    end
    F["version"]="0.0.1"
    F["uuid"]= string(uuid1())
    return PMOModel(F)
end


pmo(P::Vector, X) = model(P,X,"polynomial")

function pmo(P...)
    X = PolyVar{true}[]
    for p in P
        X = union(X, variables(p[1]))
    end
    model([P...],X,"polynomial")
end
    
mom(P::Vector, X) = model(P, X, "moment")

function mom(P...)
    X = PolyVar{true}[]
    for p in P
        X = union(X, variables(p[1]))
    end
    model([P...], X, "moment")
end
    
function sdp_size(V::Vector)
    maximum(length.(size.(V)))
end

function sdp(P...)

    F = OrderedDict{String,Any}("type" => "sdp")

    n = length(P[1][1])
    
    F["nvar"] = n

    LMI = []
    LSI = []
    LSO = []

    for p in P
        if p[2]=="inf" 
            F["objective"] =  p[1]
        elseif p[2]=="sup"
            F["objective"] =  -p[1]
        elseif sdp_size(p[1])==2 && p[2]== ">=0"
            push!(LMI, p[1])
        elseif sdp_size(p[1])==2 && p[2] == "<=0"
            push!(LMI, -p[1])
        elseif p[2]== ">=0"
            push!(LSI, p[1])
            push!(LSO, 1)
        elseif p[2]== "<=0"
            push!(LSI, -p[1])
            push!(LSO, 1)
        elseif p[2] == "=0"
            push!(LSI, p[1])
            push!(LSO, 0)
        end
    end
    F["constraints"] = SDPCstr([LMI,LSI,LSO], n)
    F["version"] = "0.0.1"
    F["uuid"]= string(uuid1())
    return PMOModel(F)
end

function sdp(P::Vector)
    return sdp(P...)
end
        
function constraints(F::PMOModel)
    return getkey(F.pmo,"constraints",[])
end

function objective(F::PMOModel)
    return getkey(F.pmo,"objective",nothing)
end


function properties(P::PMOModel)
    nv = length(P["variables"])
    no = 0;
    dgo = -1

    if P[:objective] != nothing
        no = 1
        dgo = maxdegree(P["objective"][1])
    end
    nz=0
    dgz=-1
    ns=0
    dgs=-1
    if P[:constraints] != nothing
        for c in P["constraints"]
            if c[2]=="=0"
                nz+=1
                dgz = max(dgz, maxdegree(c[1]))
            else
                ns+=1
                dgs = max(dgs, maxdegree(c[1]))
            end
        end
    end
    name = P["name"]
    return [name, nv, no, dgo, nz, dgz, ns, dgs]
end

function Base.vec(F::PMOModel)
    if F[:objective] == nothing 
        return [(c.ctr, c.set.val) for c in F["constraints"]]
    end
    P = [(F["objective"].ctr, F["objective"].set.val)]
    if F[:constraints] != nothing 
        for c in F["constraints"]
            push!(P, (c[1],c[2].val))
        end
    end
    return P
end

function PMOdoc(P::PMOModel)
    if haskey(P.model,"doc")
        println(P["doc"])
    end
end
