using LibGit2, UUIDs, JuliaDB

import Base: getindex
export register, update, getdata


function git(cmd)
    insert!(cmd.exec,1,"git")
    run(pipeline(cmd, stdout=devnull, stderr=devnull))
end

function local_data_path()
    return joinpath(homedir(), ".julia", "PMO/data")
end

function local_registry_path()
    return joinpath(homedir(), ".julia", "PMO/data/registries")
end

function update_data()
    datapath=local_data_path()
    if !ispath(datapath)
        LibGit2.clone(PMO_GIT_DATA_URL,local_data_path())
        @info "PMO clone "*PMO_GIT_DATA_URL
    else
        git(`-C $datapath pull`) 
        @info "PMO pull data"
    end
    return datapath
end

function pull_data()
    datapath = local_data_path()
    if !ispath(datapath)
        LibGit2.clone(PMO_GIT_DATA_URL,local_data_path())
        @info "PMO clone "*PMO_GIT_DATA_URL
    else
        git(`-C $datapath pull`) 
        @info "PMO pull data"
    end
    return datapath
end

function update()
    datapath = local_data_path()
    if ispath(datapath)
        git(`-C $datapath pull`) 
        @info "PMO update data"
    end
end

function add_data(file::String, F::PMO.Data)
    datapath = pull_data()
    datafile = joinpath("pmo", file*".json")
    i = 0
    while isfile(joinpath(datapath,datafile)) && i < 100
        @info "PMO data file $datafile already exists"
        i += 1
        datafile = joinpath("pmo", file*"."*string(i)*".json")
    end

    PMO.write(joinpath(datapath,datafile),F)
    git(`-C $datapath add $datafile `)
    git(`-C $datapath commit -a -m "add $file.json" `)
    git(`-C $datapath push origin master`)
    @info "PMO add data file $datafile"
    @info "PMO update data"
    return datafile, datapath
end

function rm_data(file::String)
    datapath = local_data_path()
    datafile = joinpath(datapath,"pmo", file*".json")
    if isfile(datafile)
        git(`-C $datapath rm $datafile`) 
        git(`-C $datapath commit -a -m "rm $file"`) 
        git(`-C $datapath push origin master`) 
        @info "PMO remove data file \"pmo/"*file*".json\""
    end
    return nothing
end

function add_registry(V::Vector, name::String="index-pmo")
    registpath = local_registry_path()
    regist_io  = open(joinpath(registpath,name*".csv"),"a")
    print(regist_io,V[1])
    for i in 2:length(V)
        print(regist_io, ",", V[i])
    end
    println(regist_io)
    close(regist_io)
end

function update_registry()
    datapath = local_data_path()
    if ispath(datapath)
        git(`-C $datapath pull`) 
        @info "PMO update registries"
    end
    return datapath
end

function register(F::PMO.Data; file="", url::String="")
    u = uuid1()
    if file == ""
        datafile = string(u)
    else
        datafile = file
    end
    if url==""
        newfile, pth = add_data(datafile,F)
        dataurl = joinpath(PMO_RAW_DATA_URL, newfile)
    else
        dataurl = joinpath(url,datafile)
    end
    datapath = local_data_path()
    add_registry([string(u), F["name"], dataurl] )
    
    git(`-C $datapath commit -a -m "add to index $newfile"`) 
    git(`-C $datapath push origin master`) 
    @info "PMO register $newfile"

    update_registry()
    return u, datafile 
end

function table(name::String="index-pmo")
    PMO.DataBase(JuliaDB.loadtable(joinpath(local_registry_path(), name*".csv")))
end


function read_uuid(t, uuid)
    url = filter(x-> x.uuid==uuid,t)[1][:url]
    readurl(url)
end

function getdata(name::String)
    n = length(PMO_RAW_DATA_URL)+6
    if isfile(name)
        return read(name)
    end
    file = joinpath(local_data_path(),"pmo",name[n:end])
    if isfile(file)
        return read(file)
    else
        @warn "$file does not exist"
        return nothing
    end
end

function Base.getindex(DB::PMO.DataBase, i::Int64)
    getdata(DB.db[i][:url])
end

function Base.getindex(DB::PMO.DataBase, s::String)
    L = filter(x-> match(Regex(s), x.name) !== nothing, DB.db)
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
