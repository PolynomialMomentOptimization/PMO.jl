using DynamicPolynomials, JSON
#include("../src/PMO.jl")
using PMO

X = @polyvar x y

o = x^2*y^2+x^4-y^3

g  = x^2 + Float64(pi)*y^2 -2
g2 = x

h = 2*y^2-y


F  = pmo_pol((o,"inf"),
             (g,"<=0"),
             (g2-1, ">=0"),
             (h,"=0"))

F["doc"]=
"""
This is a documentation text.
Several lines 
  - We have this
  - We have that

"""
JSON.print(F)
PMO.save("tmp.json",F)
G  = PMO.readfile("tmp.json")
JSON.print(G)


o1 = x^2*y^2+x^4-y^3
o2 = x*y

g1  = x^2 + Float64(pi)*y^2 -2
g2 = x

h1 = 2*y^2-y
h2 = x^2+y*2.1*x*y

F  = pmo_moment(([o1,o2],"inf"),
                ([g1,0],">=0"),
                ([0,g2], ">=0"),
                ([h1, h2], "=0 *")
                )

JSON.print(F)
PMO.save("tmp.json",F)
G  = PMO.readfile("tmp.json")
JSON.print(G)


using LinearAlgebra

M11 = Symmetric([2 -1 0; 0 2 0; 0 0 2])
M13 = Symmetric([2 0 -1; 0 2 0; 0 0 2])
M21 = [1 0; 0 -1]
M22 = [0 3; 3 0 ]
M20 = [0 -1; -1 2]

F  = pmo_sdp(([1,2,3], "inf"),
             ([M11, 0, M13],">=0"),
             ([M21, M22, 0, M20],">=0"),
             ([1.1,2,0,-4], "=0"),
             ([0,-1.2,3,-1],"<=0"),
             )
F["name"] = "example0"
F["doc"] =
    """
    This is an example for testing purposes.
    Nothing special.
    """
F["keywords"] =
    """
    #sdp
    #optimization
    #matrix

    """
JSON.print(F)
PMO.save("tmp.json",F)
G  = PMO.readfile("tmp.json")
JSON.print(G)

