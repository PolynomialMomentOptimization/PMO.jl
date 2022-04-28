using PMO, DynamicPolynomials

X = @polyvar x y
motz = x^4*y^2 + x^2*y^4 + 1 - 3*x^2*y^2


Motz = PMO.polynomial((motz,"inf"), (4-x^2-y^2, ">=0") )
Motz[:name] = "Motzkin bounded in B2"
Motz[:author] = "My Name"
PMO.register(Motz)


t = PMO.database()
P = t[end]
P[:version] = "0.0.2"

PMO.push(P)

PMO.rm(P)

