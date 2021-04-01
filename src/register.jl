using LibGit2, UUIDs, JuliaDB

import Base: getindex
import JuliaDB: select
export register, init, update, getdata, getfile, push, select


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

function init()
    datapath=local_data_path()
    if !ispath(datapath)
        LibGit2.clone(PMO_GIT_DATA_URL,local_data_path())
        @info "PMO clone "*PMO_GIT_DATA_URL
    else
        git(`-C $datapath checkout`) 
        @info "PMO checkout data"
    end
    return datapath
end

function update()
    datapath = local_data_path()
    if !ispath(datapath)
        LibGit2.clone(PMO_GIT_DATA_URL,local_data_path())
        @info "PMO clone "*PMO_GIT_DATA_URL
    else
        git(`-C $datapath pull`) 
        @info "PMO update data"
    end
    return datapath
end

function update(DB::PMO.DataBase)
    update()
    DB.db= JuliaDB.loadtable(joinpath(local_registry_path(), "index-pmo.csv"))
end

function update_index(uuid::String, name, url)
    (tmppath, tmpio) = mktemp()
    file = joinpath(PMO.local_registry_path(), "index-pmo.csv")
    io = open(file) 
    for line in eachline(io, keep=true) # keep so the new line isn't chomped

        if occursin(uuid,line)
            nwline = uuid*","*name*","*url*"\n"
            write(tmpio, nwline)
        else
            write(tmpio, line)
        end

    end
    close(tmpio)
    close(io)
    mv(tmppath, file, force=true)

end

function rm_index(uuid::String)
    (tmppath, tmpio) = mktemp()
    file = joinpath(PMO.local_registry_path(), "index-pmo.csv")
    io = open(file) 
    for line in eachline(io, keep=true) 
        if !occursin(uuid,line)
            write(tmpio, line)
        end
    end
    close(tmpio)
    close(io)
    mv(tmppath, file, force=true)

end

function PMO.rm(t, F::PMO.Data)
    n = length(PMO.PMO_RAW_DATA_URL)+7

    row = filter(r-> (r.uuid == F[:uuid]), t.db)
    if length(row) != 0


        PMO.rm_index(F[:uuid])
        # t.db = filter(r-> (r.uuid != F[:uuid]), t.db)
        # indexfile = joinpath(datapath,"registries/index-pmo.csv")
        # PMO.write(indexfile, t.db)

        datapath = PMO.local_data_path()
        file = row[1][:url][n:end]
        try 
            PMO.git(`-C $datapath rm json/$file `)
            PMO.git(`-C $datapath commit -a -m "rm $file" `)
            PMO.git(`-C $datapath push origin master`)
        catch
            @warn "data not found"
            return
        end
        @info "PMO remove data $file"
    end
end

function add_data(file::String, F::PMO.Data)
    datapath = update()
    datafile = file
    i = 0
    while isfile(joinpath(datapath, "json", datafile)) && i < 100
        @info "PMO data $datafile already exists"
        i += 1
        if endswith(file,".json")
            datafile = file[1:length(file)-5]*"."*string(i)*".json"
        else
            datafile = file*"."*string(i)*".json"
        end
    end
    try 
        PMO.write(joinpath(datapath,"json",datafile),F)
        git(`-C $datapath add json/$datafile `)
        git(`-C $datapath commit -a -m "add $datafile" `)
        git(`-C $datapath push origin master`)
    catch
        rm(joinpath(datapath,"json",datafile)) 
        @warn "git push failed; data not added"
        return
    end
    @info "PMO add data $datafile"

    return datafile, datapath
end

function rm_data(file::String)
    datapath = local_data_path()
    datafile = joinpath(datapath,"json", file*".json")
    if isfile(datafile)
        try
            git(`-C $datapath rm $datafile`) 
            git(`-C $datapath commit -a -m "rm $file"`) 
            git(`-C $datapath push origin master`)
        catch
            @warn "git push failed; data not removed"
            return 
        end
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

function register_data(F::PMO.Data; file="", url::String="")
    if file == ""
        datafile = F[:uuid]*".json"
    else
        if endswith(file, ".json")
            datafile = file
        else
            datafile = file*".json"
        end
    end
    if url==""
        newfile, pth = add_data(datafile,F)
        dataurl = joinpath(PMO_RAW_DATA_URL, "json", newfile)
    else
        dataurl = joinpath(url,datafile)
    end
    datapath = local_data_path()
    add_registry([F["uuid"], F["name"], dataurl] )
    git(`-C $datapath commit -a -m "add to index $newfile"`) 
    git(`-C $datapath push origin master`) 
    @info "PMO update registery"

    update()
    return [F["uuid"], datafile, dataurl]
end

register = register_data


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

function Base.getindex(DB::PMO.DataBase, I::UnitRange{Int64})
    [getdata(DB.db[i][:url]) for i in I]
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

function Base.getindex(DB::PMO.DataBase, s::Symbol)
    select(DB.db,s)
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

"""
 Get the filemane of the data if the data is in the data base or the uuid as a name 
 and a boolean true ifit is a new data; false if it is the database
"""
function getfile(DB::PMO.DataBase, F::PMO.Data, name = "")
    uuid = F[:uuid]
    if uuid == nothing
        uuid = string(uuid1())
        F[:uuid] = uuid
        @info "new uuid $uuid"
        if name == ""
            name = uuid
        end
        return name*".json", true
    else
        L = filter(x-> x.uuid==F[:uuid], DB.db)
        if length(L) >0
            file = (L[1].url)[length(PMO.PMO_RAW_DATA_URL)+7:end]
            return file, false
        else
            if name == ""
                name = F[:uuid]
            end
            return name*".json", true
        end
    end
end


"""
 Push the data in the database, update the file, commit and update the database.
  
 If no uuid or no version is available, a value is generated and attributed.
"""
function push(DB::PMO.DataBase, F::PMO.Data; file = "")
    datapath = PMO.local_data_path()
    if F[:uuid] == nothing
        F[:uuid]= string(uuid1())
        @info "new uuid $uuid"
    end
    if F[:version] == nothing
        F[:version] = "0.0.1"
    end
    if F[:author] == nothing
        @warn "data[:author] not defined; data not pushed to database"
        return 
    end

    filename, isnew = getfile(DB, F, file)
    datafile = joinpath(datapath, "json", filename)
    if isnew
        rg = register_data(F; file = filename)
        nrow = JuliaDB.table( [rg[1]], [rg[2]], [rg[3]]; names=[:uuid,:name,:url])
        DB.db = merge(DB.db, nrow)
        @info "PMO update table"
    else
        PMO.write(datafile, F)
        PMO.update_index(F[:uuid],F[:name], PMO.geturl(DB,F[:uuid]))
        try
            PMO.git(`-C $datapath commit -a -m "update $filename" `)
            PMO.git(`-C $datapath push origin master `)
        catch
            @warn "same data; no commit and push"
            return 
        end
        @info "PMO push data $filename"
    end

end

