using DynamicPolynomials, JSON
using PMO

using LinearAlgebra

M11 = Symmetric([2 -1 0; 0 2 0; 0 0 2])
M13 = Symmetric([2 0 -1; 0 2 0; 0 0 2])
M21 = [1 0; 0 -1]
M22 = [0 3; 3 0 ]
M20 = [0 -1; -1 2]

F  = PMO.sdp(([1,2,3], "inf"),
             ([M11, 0, M13],">=0"),
             ([M21, M22, 0, M20],">=0")
             )
F["name"] = "My first example"
JSON.print(F)
PMO.write("tmp.json",F)
G  = PMO.read("tmp.json")

JSON.print(G)
println()
