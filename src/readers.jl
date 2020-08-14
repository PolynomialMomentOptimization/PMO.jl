function read_var(P)
    if haskey(P,"variables")
        return [PolyVar{true}(x) for x in P["variables"]]
    elseif haskey(P,"nvar")
        return (@polyvar x[1:P["nvar"]])[1]
    end
end

function read_polynomial_cstr1(p,X)
    pol = 0 
    for tm in p["polynomial"]["terms"]
        m = tm[1]
        if length(tm)>1
            for i in 1:length(tm[2])
                if length(tm) >2
                    m*= X[tm[3][i]]^tm[2][i]
                    else
                    m*= X[i]^tm[2][i]
                end
            end
        end
        pol = pol+m
    end
    return (pol,p["set"])
end

function read_polynomial_cstr(P::Vector,X)
    R = Any[]
    for p in P
        push!(R, read_polynomial_cstr1(p,X))
    end
    return PolynomialCstr(R,X)
end

function read_moment_cstr1(p,X,nu)

    c = p["moments"]["terms"][1][1]*one(Polynomial{true,Int64})
    pol = fill(zero(c), nu)

    s = p["set"]
    for tm in p["moments"]["terms"]
        m = tm[1]
        k = tm[2]
        if k != 0
            if length(tm)>2
                for i in 1:length(tm[3])
                    if length(tm) >3
                        m*= X[tm[4][i]]^tm[3][i]
                    else
                        m*= X[i]^tm[3][i]
                    end
                end
            end
            pol[k] = pol[k]+m
        end
    end
    return  (pol,s)
end

function read_moment_cstr(P::Vector,X, nu::Int64)
    R = Any[]
    for p in P
        push!(R, read_moment_cstr1(p,X,nu))
    end
    return MomentCstr(R,X,nu)
end


function read_sdp_cstr(C, nvar::Int64)
    LMI = Any[]
    for i in 1:C["nlmi"]
        push!(LMI,Any[spzeros(C["msizes"][i],C["msizes"][i]) for k in 1:nvar+1])
    end
    if haskey(C,"lmi_symat")
        for t in C["lmi_symat"]
            k = (t[2] == 0 ? nvar+1 : t[2])
            l = t[3]
            i = t[4]
            j = t[5]
            LMI[l][k][i,j] = t[1]
            if i != j LMI[l][k][j,i] = t[1] end
        end
    end
    if haskey(C,"lmi_lrmat")
        rk = Dict{Vector{Int64},Int64}()
        for t in C["lmi_lrmat"]
            l = t[2]
            nv = (t[3] == 0 ? nvar+1 : t[3])
            r = t[4]
            rk[[l,nv]] = max(r, get(rk,[l,nv],0))
        end
        for (idx,r) in rk
            l = idx[1]
            k = idx[2]
            LMI[l][k] = [spzeros(C["msizes"][l]) for i in 1:r]
        end
        for t in C["lmi_lrmat"]
            l = t[2]
            nv = (t[3] == 0 ? nvar+1 : t[3])
            i = t[4]
            j = t[5]
            LMI[l][nv][i][j] = t[1]
        end
    end
    
    LSI = Any[]
    LSO = Any[]
    if haskey(C, "nlsi")
        LSI=spzeros(C["nlsi"],nvar+1)
        for t in C["lsi_mat"]
            i = t[2]
            j = t[3]
            LSI[i,j] = t[1]
        end
        for k in 1:C["nlsi"]
            LSI[k,nvar+1] = - C["lsi_vec"][k]
        end

        LSO = C["lsi_op"]
    end
    return SDPCstr([LMI,LSI,LSO], nvar);
end


function read_constraint(type::String,C,X,nu)

    if type == "polynomial"
        return read_polynomial_cstr(C,X)
    elseif type == "moment"
        return read_moment_cstr(C,X,nu)
    else
        return read_sdp_cstr(C,length(X))
    end
end

#----------------------------------------------------------------------
function read_polynomial_obj(O,X)
    PolynomialObj(read_polynomial_cstr1(O,X)...,X)
end

function read_moment_obj(O,X,nu)
    MomentObj(read_moment_cstr1(O,X,nu)...,X)
end

function read_sdp_obj(O, nvar::Int64)
    SDPObj(O)
end
        
function read_objective(type::String,C,X,nu)
    if type == "polynomial"
        return read_polynomial_obj(C,X)
    elseif type == "moment"
        return read_moment_obj(C,X,nu)
    else
        return read_sdp_obj(C,length(X))
    end
end

function read_data(F::OrderedDict)
    nu = (haskey(F,"nms") ? F["nms"] : 1)
    
    X = read_var(F)
    
    nvar = F["nvar"]
    if haskey(F, "objective")
        F["objective"]   = read_objective(F["type"],
                                          F["objective"],X,nu)
    end

    
    if haskey(F,"constraints")
        F["constraints"] = read_constraint(F["type"],
                                           F["constraints"], X, nu)
    end
    return PMOData(F)
end

function parse(s::String)
    F = JSON.parse(s; dicttype=DataStructures.OrderedDict)
    read_data(F)
end

function readfile(file::String)
    F = JSON.parsefile(file; dicttype=DataStructures.OrderedDict)
    read_data(F)
end

function readurl(url::String)
    p = HTTP.get(url)
    F = JSON.parse(String(p.body); dicttype=DataStructures.OrderedDict)
    PMOData(F)
end

