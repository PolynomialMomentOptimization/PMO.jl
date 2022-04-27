export pmo, @pmo

const FCT = Dict{String,Function}()

FCT["test"] = function(args...)
    println("This test is doing nothing but printing this message.")
end

function pmo(args...)
    name = String(args[1])
    if haskey(FCT,name)
        FCT[name](args[2:end]...)
    else
        t = table()
        t[name]
    end
end

macro pmo(args...)
   return pmo(String(args[1]),args[2:end]...)
end

include("functions/symmetric.jl")
