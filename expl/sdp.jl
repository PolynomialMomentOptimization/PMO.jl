using PMO, LinearAlgebra

LMI1 = [Symmetric([2 -1 0; 0 2 0; 0 0 2]),
        0,
        Symmetric([2 0 -1; 0 2 0; 0 0 2])
       ]

LMI2 = [Symmetric([1 0; 0 -1]),
        Symmetric([0 3; 3 0 ]),
        0,
        Symmetric([0 -1; -1 2])
       ]

F  = PMO.sdp(([1,2,3], "inf"),
             (LMI1,">=0"),
             (LMI2,">=0"),
             ([1.1,2,0,-4], "=0"),
             ([0,-1.2,3,-1],"<=0")
             )

F["name"] = "My first example"
F["doc"]  = "Two linear matrix inequalities, one linear scalar equality and one linear scalar inequality."

PMO.save("tmp.json",F)
G  = PMO.read("tmp.json")
PMO.json(G)


LMI1 = [Symmetric([2 1 0; 0 1 0; 0 0 0]),
        Symmetric([0 0 0; 0 1 1; 0 0 1]),
        [[0,0,1]],
        -Symmetric([0 0 0; 0 0 1; 0 0 0])]

F  = PMO.sdp(([0,0,1], "inf"),
             (LMI1, ">=0"),
             ([1, 1, 0, -1], "=0"),
             ([1, 0, 0, 0 ], ">=0"),
             ([0, 1, 0, 0 ], ">=0")
             )
F["name"] = "A second example"
F["doc"] =
    """
    one LMI with one rank-1 matrix, 3 linear scalar constraints
    """

PMO.save("tmp.json",F)
G  = PMO.read("tmp.json")
PMO.json(G)
