using DynamicPolynomials
using DataStructures

import Base: setindex!, getindex, show

export pop, constraints, objective

"""
 Polynomial Optimization Problem, as an ordered dictionnary.
"""
mutable struct Model 
    pop::DataStructures.OrderedDict{String,Any}
end

function Base.setindex!(p::POP.Model, v, k::String)  p.pop[k] = v end
function Base.setindex!(p::POP.Model, v, k::Symbol)  p.pop[string(k)] = v end

function Base.getindex(p::POP.Model, s::String)
    get(p.pop, s, nothing)
end

function Base.getindex(p::POP.Model, s::Symbol)
    get(p.pop, string(s), nothing)
end

function Base.show(io::IO,p::POP.Model)
    println(io,"Polynomial optimisation problem:")
    for (k,v) in p.pop
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
    pol::T
    set::POP.Set
    var::Any
end

function Base.show(io::IO,c::POP.Constraint)
    print(io,tuple(c.pol,c.set))
end

function constraint(p, s,  X=variables(p))
    return POP.Constraint(p,POP.Set(s),X)
end

function Base.getindex(c::POP.Constraint, i::Int64)
    if i==1
        return c.pol
    elseif i==2
        return c.set
    else
        return c.var
    end
end


"""
Construct a Polynomial Optimization Problem  from

    - O objective function (p, s) with p a polynomial and s in {"inf", "sup"}
    - P vector of constraints (p, s) with p a polynomial and s a set
    - X variables of the polynomials.

Example:
--------

    X = @polyvar x y
    POP.Model((x^2*y^2+x*y, "inf"), [(x^2+y^2-1,"<=0")], X)
"""
function Model(P::Vector, X)

    F = OrderedDict{String,Any}("variables" => [string(x) for x in X])

    C = Any[]
    for p in P
        if p[2]=="inf" || p[2] =="sup"
            F["objective"] =  constraint(Polynomial(p[1]),p[2],X)
        else
            push!(C, constraint(Polynomial(p[1]),p[2],X))
        end
    end
    if length(C)>0
        F["constraints"] = C
    end
    return POP.Model(F)
end

pop(P::Vector, X) = POP.Model(P,X)

function constraints(F::POP.Model)
    if getkey(F.pop,"constraints",0) != 0
        return F["constraints"]
    else
        return []
    end
end

function objective(F::POP.Model)
    if getkey(F.pop,"objective",0) != 0
        return F["objective"]
    else
        return nothing
    end
end


function properties(P::POP.Model)
    nv = length(P["variables"])
    no = 0;
    dgo = -1

    if P["objective"] != nothing
        no = 1
        dgo = maxdegree(P["objective"][1])
    end
    nz=0
    dgz=-1
    ns=0
    dgs=-1
    if P["constraints"] != nothing
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
    return [nv, no, dgo, nz, dgz, ns, dgs, name]
end

function Base.vec(F::POP.Model)
    if F["objective"] == nothing 
        return [(c.pol, c.set.val) for c in F["constraints"]]
    end
    P = [(F["objective"].pol, F["objective"].set.val)]
    if F["constraints"] != nothing 
        for c in F["constraints"]
            push!(P, (c[1],c[2].val))
        end
    end
    return P
end
