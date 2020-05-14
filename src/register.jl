using LibGit2, UUIDs, JuliaDB

export register, gettable, update
    
function git(cmd)
    insert!(cmd.exec,1,"git")
    run(pipeline(cmd, stdout=devnull, stderr=devnull))
end

function local_data_path()
    return joinpath(homedir(), ".julia", "PMO/data")
end

function local_registry_path()
    return joinpath(homedir(), ".julia", "PMO/registries")
end

function update_data()
    datapath=local_data_path()
    if !ispath(datapath)
        LibGit2.clone(PMO_GIT_DATA_URL,local_data_path())
        @info "PMO clone "*PMO_GIT_DATA_URL
    else
        git(`-C $datapath pull`) 
        @info "PMO update data"
    end
    return datapath
end

function update_registry()
    registpath=local_registry_path()
    if !ispath(registpath)
        LibGit2.clone(PMO_GIT_REGISTRY_URL,local_registry_path())
        @info "PMO clone "*PMO_GIT_REGISTRY_URL
    else
        git(`-C $registpath pull`) 
        @info "PMO update registries"
    end
    return registpath
end

function update()
    update_registry()

    datapath = local_data_path()
    if ispath(datapath)
        git(`-C $datapath pull`) 
        @info "PMO update data"
    end
end

function add_data(file::String, F::PMOModel)
    datapath = update_data()
    datafile = joinpath(datapath,"pmo", file*".json")
    if !isfile(datafile)
        PMOsave(datafile,F)
        git(`-C $datapath add $datafile `)
        git(`-C $datapath commit -a -m "add $file.json" `)
        git(`-C $datapath push origin master`)
        @info "PMO add data file \"pmo/"*file*".json\""
    else
        @warn "PMO data file \"pmo/"*file*".json\" already exists"
    end
    return file*".json", datapath
end

function rm_data(file::String)
    datapath = local_data_path()
    datafile = joinpath(datapath,"pmo", file*".json")
    git(`-C $datapath rm $datafile`) 
    git(`-C $datapath commit -a -m "rm $file"`) 
    git(`-C $datapath push origin master`) 
    @info "PMO remove data file \"pmo/"*file*".json\""
    return nothing
end

function add_registry(V::Vector, name::String="index-data")
    registpath = local_registry_path()
    regist_io  = open(joinpath(registpath,"csv",name*".csv"),"a")
    print(regist_io,V[1])
    for i in 2:length(V)
        print(regist_io, ",", V[i])
    end
    println(regist_io)
    close(regist_io)
end

function register(F::PMOModel; file="", url::String="", doc::String="")
    u = uuid1()
    if file == ""
        datafile = string(u)
    else
        datafile = file
    end
    if url==""
        add_data(datafile,F)
        dataurl = joinpath(PMO_RAW_DATA_URL, datafile*".json")
    else
        dataurl = joinpath(url,datafile*".json")
    end
    registpath= update_registry()
    docurl=doc

    add_registry([string(u), F["name"], dataurl, docurl] )
    add_registry([string(u), PMO_properties(F)...], "PolynomialOptimizationProblems")
    
    git(`-C $registpath commit -a -m "add to index pmo/$file"`) 
    git(`-C $registpath push origin master`) 
    @info "PMO register data "*datafile
    return u, datafile 
end


function gettable(name::String="index-data")
    JuliaDB.loadtable(joinpath(local_registry_path(),"csv", name*".csv"))
end

function read_uuid(uuid, t)
    url = filter(x-> x.uuid==uuid,t)[1][:url]
    readurl(url)
end
