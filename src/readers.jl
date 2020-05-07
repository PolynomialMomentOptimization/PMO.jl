function format_polynomial(p,X)
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

function format_moments(p,X)
    c = p["moments"]["terms"][1][1]*one(Polynomial{true,Int64})
    
    pol = fill(zero(c), p["moments"]["nu"])
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

function format(p,X)
    if haskey(p,"polynomial")
        return format_polynomial(p,X)
    elseif haskey(p,"moments")
        return format_moments(p,X)
    end
end

function format(F::OrderedDict)
    C = Any[]
    X = [PolyVar{true}(x) for x in F["pop"]["variables"]]
    for p in F["pop"]["constraints"]
        push!(C,POP.format(p,X))
    end
    F["pop"]["constraints"] = C
    if getkey(F["pop"], "objective", false) != false
        F["pop"]["objective"]   = POP.format(F["pop"]["objective"],X)
    end
    F["variables"]   = [string(x) for x in X]
    return POP.Model(F["pop"])
end

function parse(s::String)
    F = JSON.parse(s; dicttype=DataStructures.OrderedDict)
    POP.format(F)
end

function read(file::String)
    F = JSON.parsefile(file; dicttype=DataStructures.OrderedDict)
    POP.format(F)
end

function url(url::String)
    p = HTTP.get(url)
    POP.parse(String(p.body))
end

