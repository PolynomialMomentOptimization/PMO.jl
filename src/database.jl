import Base: getindex, length
import JuliaDB: select

function table(name::String="")
    if name == ""
        datapath=local_data_path()
        if !ispath(datapath)
            LibGit2.clone(PMO_GIT_DATA_URL,local_data_path())
            @info "PMO clone "*PMO_GIT_DATA_URL
        end
        PMO.DataBase(JuliaDB.loadtable(joinpath(local_registry_path(), "index-pmo.csv")))
    else
        PMO.DataBase(JuliaDB.loadtable(name))
    end
end


function getdata(name::String)
    n = length(PMO_RAW_DATA_URL)+7
    if isfile(name)
        return read(name)
    end
    file = joinpath(local_data_path(),"json", name[n:end])
    if isfile(file)
        return read(file)
    else
        @warn "file $file does not exist"
        return nothing
    end
end

function Base.getindex(DB::PMO.DataBase, i::Int64)
    getdata(DB.db[i][:url])
end
import Base: getindex, iterate, collect


function Base.getindex(DB::PMO.DataBase, I::UnitRange{Int64})
    [getdata(DB.db[i][:url]) for i in I]
end

function Base.getindex(DB::PMO.DataBase, s::String)
    L = filter(x-> match(Regex(s,"i"), x.name) !== nothing, DB.db)
    [getdata(p[:url]) for p in L]
end

function Base.getindex(DB::PMO.DataBase, reg::Regex)
    L = filter(x-> match(reg, x.name) !== nothing, DB.db)
    R = Any[]
    for p in L
        push!(R, getdata(p[:url]))
    end
    R
end

function Base.getindex(DB::PMO.DataBase, s::Symbol)
    select(DB.db,s)
end

function Base.getindex(DB::PMO.DataBase, fct::Function)
    L = filter(x-> fct(x), DB.db)
    [ getdata(p[:url]) for p in L ]
end


function Base.length(DB::PMO.DataBase)
    length(DB.db)
end

function Base.lastindex(DB::PMO.DataBase)
    lastindex(DB.db)
end

function Base.iterate(DB::PMO.DataBase, i::Tuple{Base.OneTo{Int64},Int64} = (Base.OneTo(length(DB)),1))
    return iterate(DB.db,i)
end

function geturl(DB::PMO.DataBase, uuid::String)
    L = filter(x->  x.uuid == uuid, DB.db)
    return L[1].url
end

function select(DB::PMO.DataBase, reg::Regex)
    DataBase(filter(x-> match(reg, x.name) !== nothing, DB.db))
end

function select(DB::PMO.DataBase, s::String)
    DataBase(filter(x-> match(Regex(s), x.name) !== nothing, DB.db))
end

function select(DB::PMO.DataBase, fct::Function)
    DataBase(filter(x-> fct(x), DB.db))
end

function select(DB::PMO.DataBase, s::Symbol)
    select(DB.db,s)
end

