using PMO, MomentTools

t = PMO.table()
test = select(t, "Rob")[1]
d = 5
M = MomentModel(vec(test), variables(test),d)
M_sdp = poly_to_sdp(M.model, d)