using DynamicPolynomials, JSON
using PMO

X = @polyvar x y

o = x^2*y^2+x^4-y^3

g  = x^2 + Float64(pi)*y^2 -2
g2 = x

h = 2*y^2-y


P  = pmo_pol((o,"inf"),
             (g,"<=0"),
             (g2-1, ">=0"),
             (h,"=0"))

P["doc"]=
"""
This is a documentation text.
Several lines 
  - We have this
  - We have that

"""
JSON.print(P)
PMO.write("tmp.json",P)
G  = PMO.read("tmp.json")
JSON.print(G)


o1 = x^2*y^2+x^4-y^3
o2 = x*y

g1  = x^2 + Float64(pi)*y^2 -2
g2 = x

h1 = 2*y^2-y
h2 = x^2+y*2.1*x*y

M  = pmo_moment(([o1,o2],"inf"),
                ([g1,0],">=0"),
                ([0,g2], ">=0"),
                ([h1, h2], "=0 *")
                )

JSON.print(M)
PMO.write("tmp.json",M)
G  = PMO.read("tmp.json")
JSON.print(G)


using LinearAlgebra

LMI1 = [Symmetric([2 -1 0; 0 2 0; 0 0 2]),
        0,
        Symmetric([2 0 -1; 0 2 0; 0 0 2])
        ]

LMI2 = [Symmetric([1 0; 0 -1]),
        Symmetric([0 3; 3 0 ]),
        0,
        Symmetric([0 -1; -1 2])
        ]

S  = PMO.sdp(([1,2,3], "inf"),
             (LMI1,">=0"),
             (LMI2,">=0"),
             ([1.1,2,0,-4], "=0"),
             ([0,-1.2,3,-1],"<=0"),
             )
S["name"] = "example0"
S["doc"] =
    """
    This is an example for testing purposes.
    Nothing special.
    """
S["keywords"] =
    """
    #sdp
    #optimization
    #matrix

    """
JSON.print(S)
PMO.write("tmp.json",S)
G  = PMO.read("tmp.json")
JSON.print(G)

