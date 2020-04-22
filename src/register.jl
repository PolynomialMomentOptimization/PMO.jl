using LibGit2, UUIDs, JuliaDB

export register, gettable, update
    
function git(cmd)
    insert!(cmd.exec,1,"git")
    run(pipeline(cmd, stdout=devnull, stderr=devnull))
end

function local_data_path()
    return joinpath(homedir(), ".julia", "POP/data")
end

function local_registry_path()
    return joinpath(homedir(), ".julia", "POP/registries")
end

function update_data()
    datapath=local_data_path()
    if !ispath(datapath)
        LibGit2.clone(POP.GIT_DATA_URL,local_data_path())
        @info "POP clone "*POP.GIT_DATA_URL
    else
        git(`-C $datapath pull`) 
        @info "POP update data"
    end
    return datapath
end

function update_registry()
    registpath=local_registry_path()
    if !ispath(registpath)
        LibGit2.clone(POP.GIT_REGISTRY_URL,local_registry_path())
        @info "POP clone "*POP.GIT_REGISTRY_URL
    else
        git(`-C $registpath pull`) 
        @info "POP update registries"
    end
    return registpath
end

function update()
    update_registry()

    datapath = local_data_path()
    if ispath(datapath)
        git(`-C $datapath pull`) 
        @info "POP update data"
    end
end

function add_data(file::String, F::POP.Model)
    datapath = update_data()
    datafile = joinpath(datapath,"pop", file*".json")
    if !isfile(datafile)
        POP.save(datafile,F)
        git(`-C $datapath add $datafile `)
        git(`-C $datapath commit -a -m "add $file.json" `)
        git(`-C $datapath push origin master`)
        @info "POP add data file \"pop/"*file*".json\""
    else
        @warn "POP data file \"pop/"*file*".json\" already exists"
    end
    return file*".json", datapath
end

function rm_data(file::String)
    datapath = local_data_path()
    datafile = joinpath(datapath,"pop", file*".json")
    git(`-C $datapath rm $datafile`) 
    git(`-C $datapath commit -a -m "rm $file"`) 
    git(`-C $datapath push origin master`) 
    @info "POP remove data file \"pop/"*file*".json\""
    return nothing
end

function add_registry(V::Vector, name::String="index-pop")
    registpath = local_registry_path()
    regist_io  = open(joinpath(registpath,"csv",name*".csv"),"a")
    print(regist_io,V[1])
    for i in 2:length(V)
        print(regist_io, ",", V[i])
    end
    println(regist_io)
    close(regist_io)
end

function register(F::POP.Model; file="", url::String="", doc::String="")
    u = uuid1()
    if file == ""
        datafile = string(u)
    else
        datafile = file
    end
    if url==""
        add_data(datafile,F)
        dataurl = joinpath(POP.RAW_DATA_URL, datafile*".json")
    else
        dataurl = joinpath(url,datafile*".json")
    end
    registpath= update_registry()
    docurl=doc

    add_registry([string(u), F["name"], dataurl, docurl] )
    add_registry([string(u), POP.properties(F)...], "PolynomialOptimizationProblems")
    
    git(`-C $registpath commit -a -m "add to index pop/$file"`) 
    git(`-C $registpath push origin master`) 
    @info "POP register data "*datafile
    return u, datafile 
end


function gettable(name::String="index-pop")
    JuliaDB.loadtable(joinpath(local_registry_path(),"csv", name*".csv"))
end

