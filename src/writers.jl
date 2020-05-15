#----------------------------------------------------------------------
function json_polynomial_terms(pol::Polynomial, X)
    terms = String[]
    for t in pol
        V = Int64[]
        E = Int64[]
        for i in 1:length(X)
            d = maxdegree(t,X[i])
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

#----------------------------------------------------------------------
function JSON.lower(C::PolynomialCstr)
    R = Any[]
    for c in C.cstr
        M = OrderedDict{String,Any}()
        M["set"] = c[2]
        pol=c[1]
        M["polynomial"] = OrderedDict(
            "coeftype" => string(eltype(pol.a)),
            "terms" => json_polynomial_terms(pol, C.var)
        )
        push!(R,M)
    end
    return R
end

#----------------------------------------------------------------------
function JSON.lower(c::PolynomialObj)
    M = OrderedDict{String,Any}()
    M["set"] = c.set
    pol=c.obj
    M["polynomial"] = OrderedDict(
        "coeftype" => string(eltype(pol.a)),
        "terms" => json_polynomial_terms(pol, c.var)
    )
    return M
end

#----------------------------------------------------------------------
function json_moment_terms(P::Vector, X)
    terms = String[]
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

   
function JSON.lower(C::MomentCstr)
    R = Any[]
    for c in C.cstr
        M = OrderedDict{String,Any}()
        M["set"] = c[2]
        pol=c[1]
        M["moments"] = OrderedDict(
            "coeftype" => string(eltype(pol[1].a)),
            "terms" => json_moment_terms(pol, C.var)
        )
        push!(R,M)
    end
    return R
end

function JSON.lower(c::MomentObj)
    M = OrderedDict{String,Any}()
    M["set"] = c.set
    pol=c.obj
    M["moments"] = OrderedDict(
        "coeftype" => string(eltype(pol[1].a)),
        "terms" => json_moment_terms(pol, c.var)
    )
    return M
end
#----------------------------------------------------------------------
function JSON.lower(c::SDPCstr)
    M = OrderedDict{String,Any}()

    LMISY = String[]
    LMILR = String[]
    LDM   = Int64[]
    for l in 1:length(c.cstr[1])
        V = c.cstr[1][l]
        push!(LDM, size(V[1],1))
        for k in 1:length(V)
            kv = ( k> c.nvar  ? 0 : k)
            if length(size(V[k])) == 2
                for i in 1:size(V[k],1)
                    for j in 1:i
                        if V[k][i,j] != 0
                            push!(LMISY, json(Any[ V[k][i,j], l, kv, i, j]))
                        end
                    end
                end
            else
                for i in 1:length(V[k])
                    for j in 1:length(V[k][i])
                        if V[k][i][j] != 0
                            push!(LMILR, json(Any[ V[k][i][j], l, kv, i, j]))
                        end
                    end
                end
            end
        end
    end

    M["nlmi"] = length(LDM)
    M["msizes"] = json(LDM)
    if length(LMISY) != 0
        M["lmi_symat"] = LMISY
    end
    if length(LMILR) != 0
        M["lmi_lrmat"] = LMILR
    end

    LSI = String[]
    csi = c.cstr[2]
    for i in 1:length(csi)
        for j in 1:length(csi[i])
            nv = ( j> c.nvar  ? 0 : j)
            if csi[i][j] != 0
                push!(LSI, json(Any[csi[i][j], i, nv]))
            end
        end
    end
    if length(LSI) != 0
        M["nlsi"]    = length(c.cstr[3])
        M["lsi_mat"] = LSI
        M["lsi_op"] = json(c.cstr[3])
    end
    return M
end


function JSON.lower(m::PMOData)
    return m.data
end

function JSON.json(io::IO, F::PMOData)
    s = replace(JSON.json(F,2), "\"["=>"[")
    s = replace(s,"]\""=>"]")
    print(io,s)
end

function JSON.print(F::PMOData)
    JSON.json(stdout,F)
end

function save(file::String, F::PMOData)
    fd = open(file,"w")
    JSON.json(fd,F)
    close(fd)
end

