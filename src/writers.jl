function JSON.lower(s::POP.Set)
    if typeof(s.val)==String
        s.val
    else
        json(s.val)
    end
end

function json_terms(pol, set, X)
    terms = String[]
    for t in pol
        V = Int64[]
        E = Int64[]
        for i in 1:length(X)
            d = degree(t,X[i])
            if d!= 0
                push!(V,i)
                push!(E,d)
            end
        end
        tm = Any[coefficient(t)]
        if (length(E)>0)  push!(tm,E) end
        if (length(V)!=length(X)) && (length(V)>0)
                push!(tm,V)
        end
        push!(terms,JSON.json(tm))
    end
    return terms
end

function json_terms(P::Vector, set, X)
    terms = String[]
    if typeof(set.val)<:Vector
        tm = Any[set.val[1],0]
        push!(terms, JSON.json(tm))
    end
    for i in 1:length(P)
        if P[i] != 0
            for t in P[i]
                V = Int64[]
                E = Int64[]
                for i in 1:length(X)
                    d = degree(t,X[i])
                    if d!= 0
                        push!(V,i)
                        push!(E,d)
                    end
                end
                tm = Any[coefficient(t),i]
                if (length(E)>0)  push!(tm,E) end
                if (length(V)!=length(X)) && (length(V)>0)
                    push!(tm,V)
                end
                push!(terms, JSON.json(tm))
            end
        end
    end

    return terms
end

function JSON.lower(c::POP.Constraint)

    pol = c.pol*one(Polynomial{true,Int64})
    M = OrderedDict{String,Any}()
    if typeof(c.set.val)<:Vector
        M["set"] = c.set.val[2]
        M["type"] = "mass" 
    elseif c.set.val=="inf" || c.set.val=="sup" 
        M["set"] = c.set.val
        M["type"] = "mass" 
    else
        M["set"] = c.set.val
    end

    if typeof(c.pol) <: Vector

        #assert length(pol) != 0
        M["moments"] = OrderedDict(
            "nvar" => length(c.var),
            "nu"   => length(c.pol),
            "coeftype" => string(eltype(pol[1].a)),
            "terms" => json_terms(pol, c.set, c.var)
        )

    else

        M["polynomial"] = OrderedDict(
            "nvar" => length(c.var),
            "coeftype" => string(eltype(pol.a)),
            "terms" => json_terms(pol, c.set, c.var)
        )
    end
    
    return M
end

function POP.json(io::IO, F::POP.Model)
    s = replace(JSON.json(F,2), "\"["=>"[")
    s = replace(s,"]\""=>"]")
    print(io,s)
end

function POP.json(F::POP.Model)
    POP.json(stdout,F)
end

function POP.save(file::String, F::POP.Model)
    fd = open(file,"w")
    POP.json(fd,F)
    close(fd)
end

