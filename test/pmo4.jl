using JSON;
using PMO


using LinearAlgebra

LMI1 = [Symmetric([2 1 0; 0 1 0; 0 0 0]),
        Symmetric([0 0 0; 0 1 1; 0 0 1]),
        [[0,0,1]],
        -Symmetric([0 0 0; 0 0 1; 0 0 0])]

F  = PMO.sdp(([0,0,1], "inf"),
             (LMI1, ">=0"),
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
PMO.write("tmp.json",F)
G  = PMO.read("tmp.json")
JSON.print(G)
