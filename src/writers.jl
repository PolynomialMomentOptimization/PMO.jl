function JSON.lower(s::POP.Set)
    if typeof(s.val)==String
        s.val
    else
        json(s.val)
    end
end

function JSON.lower(c::POP.Constraint)
    terms = Any[]
    pol = c.pol
    X = c.var
    for t in c.pol
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

    (OrderedDict("set"=>c.set, "polynomial"=>OrderedDict("nvar"=>length(X), "coeftype"=> typeof(pol.a[1]), "terms"=>terms)))
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

