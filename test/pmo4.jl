using JSON;
#using PMO
include("../src/PMO.jl")

using LinearAlgebra

VM = [Symmetric([2 1 0; 0 1 0; 0 0 0]),
      Symmetric([0 0 0; 0 1 1; 0 0 1]),
      [[0,0,1]],
      -Symmetric([0 0 0; 0 0 1; 0 0 0])]

F  = PMO.sdp(([0,0,1], "inf"),
             (VM, ">=0"),
             ([1, 1, 0 , -1], "=0"),
             ([1, 0, 0 ], ">=0"),
             ([0, 1, 0 ], ">=0")
             )
F["name"] = "My second example"
F["doc"] =
    """
    one LMI with one rank-1 matrix, 3 linear constraints
    """
JSON.print(F)
PMO.save("tmp.json",F)
G  = PMO.readfile("tmp.json")
JSON.print(G)
