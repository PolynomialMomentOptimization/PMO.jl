using DynamicPolynomials
include("../src/POP.jl")
#using POP

using LinearAlgebra

M11 = Symmetric([2 -1 0; -1 2 0; 0 0 2])
M13 = [2 0 -1; 0 2 0; -1 0 2]
M21 = [1 0; 0 -1]
M22 = [0 3; 3 0 ]
M20 = [0 -1; -1 2]

F  = POP.sdp([([1,2,3], "inf"),
              ([M11, 0, M13],">=0"),
              ([M21, M22, 0, M20],">=0"),
              ([1.1,2,0,-4], "=0"),
              ([0,-1.2,3,-1],"<=0"),
              ])

POP.json(F)
POP.save("tmp.json",F)
G  = POP.readfile("tmp.json")

POP.json(G)
