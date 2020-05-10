using DynamicPolynomials
using DataStructures

import Base: setindex!, getindex, show

export pop, mom, sdp, constraints, objective

"""
 Optimization Problem as an ordered dictionnary.
"""
mutable struct Model 
    prog::OrderedDict{String,Any}
    type::String
end

function Base.setindex!(p::POP.Model, v, k::String)  p.prog[k] = v end
function Base.setindex!(p::POP.Model, v, k::Symbol)  p.prog[string(k)] = v end

function Base.getindex(p::POP.Model, s::String)  get(p.prog, s, "") end

function Base.getindex(p::POP.Model, s::Symbol)  get(p.prog, string(s), nothing) end

function Base.show(io::IO,p::POP.Model)
    println(io,"Optimisation program:")
    for (k,v) in p.prog
        println(io,"  ",k, " => ",v)
    end
    return io
end

"""
 Set for the range of the polynomial values
"""
mutable struct Set
    val::Any
end

function Base.show(io::IO,s::POP.Set)
    if typeof(s.val)==String
        print(io,'"',s.val,'"')
    else
        print(io,s.val)
    end
end

"""
 Polynomial constraint as a polynomial, a set and the variables
"""
mutable struct Constraint{T}
    ctr::T
    set::POP.Set
    var::Any
end

"""
 Polynomial constraint as a polynomial, a set and the variables
"""
mutable struct SDP_Constraint{T}
    ctr::T
    set::POP.Set
    nvar::Int64
end
    
function Base.show(io::IO,c::POP.Constraint)
    print(io,tuple(c.ctr,c.set))
end

function constraint(p, s,  X=variables(p))
    return POP.Constraint(p,POP.Set(s),X)
end

function Base.getindex(c::POP.Constraint, i::Int64)
    if i==1
        return c.ctr
    elseif i==2
        return c.set
    else
        return c.var
    end
end


"""
Construct a Polynomial Optimization Problem  from

    - P vector of objective function or constraints (p, s) with p a polynomial and s a set
    - X variables of the polynomials.

Example:
--------

    X = @polyvar x y
    POP.Model([(x^2*y^2+x*y, "inf"), (x^2+y^2-1,"<=0")], X)
"""
function model(P::Vector, X, typ::String)

    F = OrderedDict{String,Any}("variables" => [string(x) for x in X])
    
    F["nvar"] = length(X)
    if typ=="mom"
        F["nmus"] = length(P[1][1])
    end
    C = POP.Constraint[]
    for p in P
        if p[2]=="inf" || p[2] =="sup"
            F["objective"] =  constraint(p[1],p[2],X)
        else
            push!(C, constraint(p[1],p[2],X))
        end
    end
    if length(C)>0
        F["constraints"] = C
    end
    return POP.Model(F, typ)
end


pop(P::Vector, X) = model(P,X,"pop")

mom(P::Vector, X) = model(P, X, "mom")

function sdp_size(V::Vector)
    maximum(length.(size.(V)))
end

function sdp(P...)

    F = OrderedDict{String,Any}()

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
    F["constraints"] = SDP_Constraint([LMI,LSI],Set(LSO), n)
    return POP.Model(F, "sdp")
end

function sdp(P::Vector)
    return sdp(P...)
end
        
function constraints(F::POP.Model)
    return getkey(F.pop,"constraints",[])
end

function objective(F::POP.Model)
    return getkey(F.pop,"objective",nothing)
end


function properties(P::POP.Model)
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

function Base.vec(F::POP.Model)
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

