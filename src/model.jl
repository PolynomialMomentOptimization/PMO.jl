using DynamicPolynomials
using DataStructures

import Base: setindex!, getindex, show

export pmo_pol, pmo_moment, pmo_sdp, constraints, objective, doc

"""
 Polynomial Moment Optimization Data as an ordered dictionnary.
"""
mutable struct PMOData
    data::OrderedDict{String,Any}
end

function PMOData(F,s) PMOData(F) end

function Base.setindex!(p::PMOData, v, k::String)  p.data[k] = v end
function Base.setindex!(p::PMOData, v, k::Symbol)  p.data[string(k)] = v end
function Base.getindex(p::PMOData, s::String)  get(p.data, s, "") end
function Base.getindex(p::PMOData, s::Symbol)  get(p.data, string(s), nothing) end

function Base.show(io::IO,p::PMOData)
    println(io,"Optimisation model:")
    for (k,v) in p.data
        println(io,"  ",k, " => ",v)
    end
    return io
end

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
 SDP  constraint.
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
Construct a Polynomial Moment Optimization data  from

    - P vector of objective function or constraints (p, s) with p a polynomial and s a set
    - X variables of the polynomials.

Example:
--------

    X = @polyvar x y
    data([(x^2*y^2+x*y, "inf"), (x^2+y^2-1,"<=0")], X)
"""
function pmodata(P::Vector, X, type::String)

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
    return PMOData(F)
end


polynomial(P::Vector, X) = pmodata(P,X,"polynomial")

function polynomial(P...)
    X = PolyVar{true}[]
    for p in P
        X = union(X, variables(p[1]))
    end
    pmodata([P...],X,"polynomial")
end

pmo_pol= polynomial
        
moment(P::Vector, X) = pmodata(P, X, "moment")

function moment(P...)
    X = PolyVar{true}[]
    for p in P
        X = union(X, variables(p[1]))
    end
    pmodata([P...], X, "moment")
end

pmo_moment = moment
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
    return PMOData(F)
end

function sdp(P::Vector)
    return pmo_sdp(P...)
end

pmo_sdp = sdp
        
function constraints(F::PMOData)
    return getkey(F.pmo,"constraints",[])
end

function objective(F::PMOData)
    return getkey(F.pmo,"objective",nothing)
end


function properties(P::PMOData)
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

function Base.vec(F::PMOData)
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

function doc(P::PMOData)
    return P["doc"]
end
