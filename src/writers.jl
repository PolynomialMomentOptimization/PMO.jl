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

    pol = c.ctr*one(Polynomial{true,Int64})
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

    if typeof(c.ctr) <: Vector

        #assert length(pol) != 0
        M["moments"] = OrderedDict(
            "coeftype" => string(eltype(pol[1].a)),
            "terms" => json_terms(pol, c.set, c.var)
        )

    else

        M["polynomial"] = OrderedDict(
            "coeftype" => string(eltype(pol.a)),
            "terms" => json_terms(pol, c.set, c.var)
        )
    end
    
    return M
end

function JSON.lower(c::POP.SDP_Constraint)
    M = OrderedDict{String,Any}()

    LMI = String[]
    LDM = Int64[]
    for l in 1:length(c.ctr[1])
        V = c.ctr[1][l]
        push!(LDM, size(V[1],1))
        for k in 1:length(V)
            kv = ( k> c.nvar  ? 0 : k)
            if length(size(V[k])) == 2
                for i in size(V[k],1)
                    for j in 1:i
                        if V[k][i,j] != 0
                            push!(LMI, json(Any[ V[k][i,j], l, kv, i, j]))
                        end
                    end
                end
            end
        end
    end
    M["msizes"] = json(LDM)
    M["lmi_mat"] = LMI

    LSI = String[]
    csi = c.ctr[2]
    for i in 1:length(csi)
        for j in 1:length(csi[i])
            nv = ( j> c.nvar  ? 0 : j)
            if csi[i][j] != 0
                push!(LSI, json(Any[csi[i][j], i, nv]))
            end
        end
    end
    M["nlsi"]    = length(c.set.val)
    M["lsi_mat"] = LSI
    M["lsi_op"] = c.set

    return M
end


function JSON.lower(m::POP.Model)
    return OrderedDict(  m.type => m.prog )
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

