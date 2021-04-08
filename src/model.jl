using DynamicPolynomials
using DataStructures

import Base: setindex!, getindex, show
import DynamicPolynomials: variables

export data, pmo_pol, pmo_moment, pmo_sdp, constraints, objective, add_constraint, variables

"""
 Polynomial Moment Optimization Data as an ordered dictionnary.
"""
mutable struct Data
    data::OrderedDict{String,Any}
end

mutable struct DataBase
    db :: JuliaDB.IndexedTables.IndexedTable
end
    
function PMO.Data(F,s) PMO.Data(F) end

function Base.setindex!(p::PMO.Data, v, k::String)
    if v == ""
        delete!(p.data,k)
    else
        p.data[k] = v
    end
end

function Base.setindex!(p::PMO.Data, v, k::Symbol)
    if v == nothing
        delete!(p.data,string(k))
    else
        p.data[string(k)] = v
    end
end
function Base.getindex(p::PMO.Data, s::String)  get(p.data, s, "") end
function Base.getindex(p::PMO.Data, s::Symbol)  get(p.data, string(s), nothing) end

function Base.show(io::IO, p::PMO.Data)
    println(io,"Optimisation model:")
    for (k,v) in p.data
        println(io,"  ",k, " => ",v)
    end
    return io
end

function add_constraint(F::PMO.Data, p, s)
    push!(F[:constraints].cstr, (p,s))
end


"""
 Polynomial constraint as a polynomial, a set and the variables
"""
mutable struct PolynomialCstr{T}
    cstr::Vector{T}
    var::Any
end


function PolynomialCstr(X)
    return PolynomialCstr([],X)
end

function Base.getindex(p::PolynomialCstr, i::Int64)  return p.cstr[i] end
function Base.setindex!(p::PolynomialCstr, v, i::Int64)
    if v == nothing
        deleteat!(p.cstr,i)
    else
        p.cstr[i] = v
    end
end

function Base.push!(C::PolynomialCstr, p, s)
    push!(C.cstr, (p,s))
end

function Base.iterate(C::PolynomialCstr, i::Int64=1)
    iterate(C.cstr,i)
end

function Base.length(C::PolynomialCstr)
    return length(C.cstr)
end

function Base.show(io::IO, C::PolynomialCstr)
    print(io, "[ ") 
    for i in 1:length(C.cstr)
        c = C.cstr[i]
        if i >1 print(io, ", ") end
        print(io, c[1])
        if typeof(c[2]) != String print(io," in") end
        print(io, " ", c[2])
    end
    print(io," ]")
    return io
end

mutable struct PolynomialObj{T}
    obj::T
    set::String
    var::Any
end

function Base.getindex(p::PolynomialObj, i::Int64)
    if i==1
        return p.obj
    else
        return p.set
    end
end

function Base.show(io::IO, O::PolynomialObj)
    print(io, O.set, " ", O.obj)
    return io
end

#----------------------------------------------------------------------
"""
 Moment constraint as a polynomial, a set and the variables
"""
mutable struct MomentCstr{T}
    cstr::Vector{T}
    var::Any
    nu:: Int64
end

function MomentCstr(X,nu::Int64) return MomentCstr([],X,nu) end

function Base.show(io::IO, C::MomentCstr)
    print(io, "[ ") 
    for i in 1:length(C.cstr)
        c = C.cstr[i]
        if i >1 print(io, ", ") end
        print(io, c[1])
        if typeof(c[2]) != String print(io," in") end
        print(io, " * ", c[2])
    end
    print(io," ]")
    return io
end


function Base.push!(C::MomentCstr, p, s)
    push!(C.cstr, (p,s))
end

function Base.iterate(C::MomentCstr, i::Int64=1)
    iterate(C.cstr,i)
end
    
mutable struct MomentObj{T}
    obj::T
    set::String
    var::Any
end

function Base.getindex(p::MomentObj, i::Int64)
    if i==1
        return p.obj
    else
        return p.set
    end
end

function Base.show(io::IO, O::MomentObj)
    print(io, O.set, " ", O.obj)
    return io
end


"""
 SDP  objective
"""
mutable struct SDPObj{T}
    obj::Vector{T}
end

function Base.getindex(p::SDPObj, i::Int64)
    return p.obj
end

"""
 SDP  constraints
"""
mutable struct SDPCstr{T}
    cstr::Vector{T}
    nvar::Int64
    dual_lr ::Any
    dual_rk ::Any
end

function Base.push!(C::SDPCstr, p, s)
    push!(C.cstr, (p,s) )
end

function Base.iterate(C::SDPCstr, i::Int64=1)
    iterate(C.cstr,i)
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
    - type in {"polynomial", "moment", "sdp"} specifies the type of optimization problem

Example:
--------

    X = @polyvar x y
    data([(x^2*y^2+x*y, "inf"), (x^2+y^2-1,"<=0")], X, "polynomial")
"""
function data(P::Vector, X, type::String = "polynomial")

    F = OrderedDict{String,Any}(
        "type"=> type,
        "variables" => [replace(replace(string(x),"]"=>""),"["=>"") for x in X]
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
            
            push!(F["constraints"],
                  p[1]*one(Polynomial{true,Int64}), p[2])
        end
    end
    F["version"]="0.0.1"
    F["uuid"]= string(uuid1())
    return PMO.Data(F)
end

function data(P...; type = "polynomial", var=[])
    if length(var)==0
        var = PolyVar{true}[]
        for p in P
            var = union(var, variables(p[1]))
        end
    end
    return data([P...],var,type)
end
    
polynomial(P::Vector, X) = data(P,X,"polynomial")

function polynomial(P...)
    X = PolyVar{true}[]
    for p in P
        X = union(X, variables(p[1]))
    end
    data([P...],X,"polynomial")
end

pmo_pol= polynomial
        
moment(P::Vector, X) = data(P, X, "moment")

function moment(P...; nms = length(P[1][1]))
    X = PolyVar{true}[]
    for p in P
        X = union(X, variables(p[1]))
    end
    F = data([P...], X, "moment")
    F[:nms] = nms
    return F
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
    F["constraints"] = SDPCstr([LMI,LSI,LSO], n, [], [])
    F["version"] = "0.0.1"
    F["uuid"]= string(uuid1())
    return PMO.Data(F)
end

function sdp(P::Vector)
    return pmo_sdp(P...)
end

pmo_sdp = sdp
        
function constraints(F::PMO.Data)
    return getkey(F.data,"constraints",[])
end

function objective(F::PMO.Data)
    return getkey(F.data,"objective",nothing)
end

function DynamicPolynomials.variables(F::PolynomialObj)  return F.var  end
function DynamicPolynomials.variables(F::PolynomialCstr) return F.var  end
function DynamicPolynomials.variables(F::MomentObj)  return F.var end
function DynamicPolynomials.variables(F::MomentCstr) return F.var end
function DynamicPolynomials.variables(F::SDPObj)  
    return ["x"*string(i) for i in 1:length(F.obj)-1]
end
function DynamicPolynomials.variables(F::SDPCstr)
    return ["x"*string(i) for i in 1:F.nvar]
end
function DynamicPolynomials.variables(F::Nothing)
    return DynamicPolynomials.PolyVar{true}[]
end
function DynamicPolynomials.variables(F::PMO.Data)
    union(variables(F[:objective]), variables(F[:constraints]))
end
function DynamicPolynomials.variables(F::Array)
    X = PolyVar{true}[]
    for p in F
        X = union(X, variables(p))
    end
    return X
end
function DynamicPolynomials.variables(x::T) where {T<:Number}
    return PolyVar{true}[]
end
function DynamicPolynomials.variables(x::String) 
    return PolyVar{true}[]
end           
function properties(P::PMO.Data)
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

function Base.vec(F::PMO.Data)
    if F["objective"] == nothing 
        return [(c[1], c[2]) for c in F["constraints"].cstr]
    end
    P = Any[]
    if F[:objective] != nothing
        push!(P, (F[:objective].obj, F[:objective].set))
    end
    if F[:constraints] != nothing 
        for c in F[:constraints].cstr
            push!(P, (c[1], c[2]))
        end
    end
    return P
end

