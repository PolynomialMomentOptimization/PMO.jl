using PMO, DynamicPolynomials
X = @polyvar x y
motz = x^4*y^2 + x^2*y^4 + 1 - 3*x^2*y^2

Motz = PMO.polynomial((motz,"inf"), (4-x^2-y^2, ">=0"))
Motz[:name] = "Motzkin bounded in B2"
PMO.register(Motz)

t = PMO.database()
m = t[end]

PMO.rm(Motz)

