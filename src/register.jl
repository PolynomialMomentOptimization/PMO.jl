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

function PMO.update(t, F::PMO.Data)

    row = filter(r-> (r.uuid == F[:uuid]), t.db)
    if length(row) == 0
        @warn "uuid not found in database"
        return
    end
    n = length(PMO.PMO_RAW_DATA_URL)+7
    file = row[1][:url][n:end]
    datapath = PMO.local_data_path()
    datafile = joinpath(datapath,"json", file)
    v = VersionNumber(F[:version])
    F[:version] = string(VersionNumber(v.major,v.minor,v.patch+1))
    PMO.write(datafile, F)
    PMO.git(`-C $datapath commit -a -m "modify $file" `)
    PMO.git(`-C $datapath push origin master`)
    @info "PMO update data $file"
end

function PMO.rm(t, F::PMO.Data)
    n = length(PMO.PMO_RAW_DATA_URL)+7

    row = filter(r-> (r.uuid == F[:uuid]), t.db)
    if length(row) != 0
        file = row[1][:url][n:end]
        datapath = PMO.local_data_path()
        PMO.git(`-C $datapath rm json/$file `)
        t.db = filter(r-> (r.uuid != F[:uuid]), t.db)
        indexfile = joinpath(datapath,"registries/index-pmo.csv")
        PMO.write(indexfile, t.db)
        PMO.git(`-C $datapath commit -a -m "rm $file" `)
        PMO.git(`-C $datapath push origin master`)
        @info "PMO remove data $file"
       
    end
end


function add_data(file::String, F::PMO.Data)
    datapath = pull_data()
    datafile = joinpath("json", file*".json")
    i = 0
    while isfile(joinpath(datapath,datafile)) && i < 100
        @info "PMO data $datafile already exists"
        i += 1
        datafile = joinpath("json", file*"."*string(i)*".json")
    end

    PMO.write(joinpath(datapath,datafile),F)
    git(`-C $datapath add $datafile `)
    git(`-C $datapath commit -a -m "add $file.json" `)
    git(`-C $datapath push origin master`)
    @info "PMO add data $datafile"
    return datafile, datapath
end

function rm_data(file::String)
    datapath = local_data_path()
    datafile = joinpath(datapath,"json", file*".json")
    if isfile(datafile)
        git(`-C $datapath rm $datafile`) 
        git(`-C $datapath commit -a -m "rm $file"`) 
        git(`-C $datapath push origin master`) 
        @info "PMO remove data file $file"
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

function register(F::PMO.Data; file="", url::String="")
    if file == ""
        datafile = F[:uuid]*".json"
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
    add_registry([F["uuid"], F["name"], dataurl] )
    git(`-C $datapath commit -a -m "add to index $newfile"`) 
    git(`-C $datapath push origin master`) 
    @info "PMO register data $newfile"

    update()
    return datafile 
end


function table(name::String="index-pmo")
    PMO.DataBase(JuliaDB.loadtable(joinpath(local_registry_path(), name*".csv")))
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


