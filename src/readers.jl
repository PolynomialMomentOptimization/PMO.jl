using SparseArrays

function read_polynomial(p,X)
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
    return  POP.Constraint(pol,POP.Set(p["set"]),X)
end

function read_moments(p,X,nu)
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
        else
            s = [m,p["set"]]
        end
    end
    return  POP.Constraint(pol,POP.Set(s),X)
end

function read_constraint(p,X,nu=1)
    if typeof(p) <: Vector
        return p;
    elseif haskey(p,"polynomial")
        return read_polynomial(p,X)
    elseif haskey(p,"moments")
        return read_moments(p,X,nu)
    else
        return p
    end
end

function read_sdp(C, nvar::Int64)
    LMI = Any[]
    for i in 1:length(C["msizes"])
        push!(LMI,[spzeros(C["msizes"][i],C["msizes"][i]) for k in 1:nvar+1])
    end
    for t in C["lmi_mat"]
        l = t[2]
        nv = (t[3] == 0 ? nvar+1 : t[3])
        i = t[4]
        j = t[5]
        LMI[l][nv][i,j] = t[1]
        if i != j LMI[l][nv][j,i] = t[1] end
    end

    LSI = Any[]
    for i in 1:C["nlsi"]
        push!(LSI, spzeros(nvar+1))
    end
    for t in C["lsi_mat"]
        l = t[2]
        nv = (t[3] == 0 ? nvar+1 : t[3])
        LSI[l][nv] = t[1]
    end
    return SDP_Constraint([LMI,LSI],Set(C["lsi_op"]), nvar);
end

function read_var(P)
    if haskey(P,"variables")
        return [PolyVar{true}(x) for x in P["variables"]]
    elseif haskey(P,"nvar")
        return (@polyvar x[1:P["nvar"]])[1]
    end
end

function read_data(P::OrderedDict)
    for (name,F) in P
        
        nu = (haskey(F,"nmus") ? F["nmus"] : 1)

        X = read_var(F)
        F["variables"]   = [string(x) for x in X]

        nvar = F["nvar"]
        if haskey(F, "objective")
            F["objective"]   = POP.read_constraint(F["objective"],X,nu)
        end

        if haskey(F,"constraints")
            if typeof(F["constraints"])<: Vector
                C = Any[]
                for p in F["constraints"]
                    push!(C,POP.read_constraint(p,X,nu))
                end
                F["constraints"] = C
            else
                F["constraints"] = read_sdp(F["constraints"],nvar)
            end
        end
        return POP.Model(F, name)
    end
end

function parse(s::String)
    F = JSON.parse(s; dicttype=DataStructures.OrderedDict)
    POP.read_data(F)
end

function readfile(file::String)
    F = JSON.parsefile(file; dicttype=DataStructures.OrderedDict)
    POP.read_data(F)
end

function readurl(url::String)
    p = HTTP.get(url)
    POP.parse(String(p.body))
end

