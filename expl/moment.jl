using DynamicPolynomials, PMO
X = @polyvar x y

f1 = x^2*y^2+x^4-y^3
f2 = x*y

g1 = x^2 + Float64(pi)*y^2 -2
g2 = x

h1 = 2*y^2-y
h2 = x^2+y*2.1*x*y


F  = PMO.moment(([f1,f2],"inf"),
                ([-g1,0],">=0"),
                ([0, g2,-1], ">=0 *"),
                ([1,-1,-1], "=0 *")
                ; nms = 2 )

PMO.write("tmp.json",F)
G = PMO.read("tmp.json")
PMO.write(G)
