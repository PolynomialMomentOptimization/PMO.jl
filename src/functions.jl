export pmo, @pmo

const FCT = Dict{String,Function}()

FCT["test"] = function(args...)
    println("This test is doing nothing but printing this message.")
end

function pmo(name::String, args...)
   if haskey(FCT,name)
       FCT[name](args...)
   else
       t = table()
       t[name]
   end
end

macro pmo(args...)
   return pmo(String(args[1]),args[2:end]) 
end

