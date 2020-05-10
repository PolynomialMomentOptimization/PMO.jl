using DynamicPolynomials, JSON
include("../src/POP.jl")
#using POP

X = @polyvar x y

o = x^2*y^2+x^4-y^3

g  = x^2 + Float64(pi)*y^2 -2
g2 = x

h = 2*y^2-y


F  = POP.pop([(o,"inf"), (g,"<=0"), (g2-1, ">=0"), (h,"=0")], X)

POP.json(F)
POP.save("tmp.json",F)
G  = POP.readfile("tmp.json")
POP.json(G)
