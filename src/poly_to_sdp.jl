export poly_to_sdp

# Consider the POP problem: min f(x) s.t. h_1(x) = ... = h_s(x) = 0 , g_1(x) >= 0, ... , g_r(x) >= 0
# We want to construct the Lasserre moment relaxation at order d of this problem:
# min y^t*c s.t. y_0 = 1, M(y) is PDS, M(g_1 y) is PSD, ..., M(g_r y) is PSD, M(h_1 y) = 0, ... , M(h_s y) =0
# where M(y) is the moment matrix and M(g_i y) are the ocalizing matrices.
# This is encoded as follows:
#  c is the vector of coefficients of f;
#  y_0 = 1 is encoded as (1, 0, ... , 0, -1);
#  The PDS constraints are put all together in a block diagonal matrix S whose blocks are M(y), M(g_1 y), ... , M(g_r y)
#  S = \sum_\alpha A_\alpha y_\alpha , where A_\alpha is the symmetric matrix associated with every moment y_\alpha

# The procedure extraction of the data from the JuMP model (inside the MomentTools one) was suggested by Benoit Legat

#---------------------------------
# Create a MomentTools model from the data 
function create_model(C::Vector, X, d::Int64)
    M = MOM.Model(X, d)
    constraint_unitmass(M)
    for c in C
        if c[2] == "inf" || c[2] == "min"
            MomentTools.objective(M, c[1], "inf")
            wobj = true
        elseif c[2] == "sup" || c[2] == "max"
            MomentTools.objective(M, c[1], "sup")
            wobj = true
        elseif c[2] == "=0"
            constraint_zero(M, c[1])
        elseif c[2] == ">=0"
            constraint_nneg(M, c[1])
        elseif c[2] == "<=0"
            constraint_nneg(M, -c[1])
        elseif isa(c[2], AbstractVector)
            constraint_nneg(M, c[1] - c[2][1])
            constraint_nneg(M, -c[1] + c[2][2])
        end
    end
    return M
end
#--------------------------------
# Build the block diagonal matrix corresponding to the PSD constraints. The first block is the moment matrix, and the others are the localizing matrices
function build_S(M)
    C = all_constraints(M.model, Vector{AffExpr}, MathOptInterface.PositiveSemidefiniteConeTriangle)
    r = length(C)
    S = reshape_vector(jump_function(constraint_object(C[1])), shape(constraint_object(C[1])))
    if r > 1
        for i in 2:r
            T = reshape_vector(jump_function(constraint_object(C[i])), shape(constraint_object(C[i])))
            S = BlockDiagonal([S, T])
        end
    end
    return Symmetric(S);
end
#---------------------------------
# Create the symmetric matrices corresponding to each moment variable. 
function PSD_matrices(M)
    S = build_S(M);
    l = length(S[:,1]);
    var = all_variables(M.model);
    A = [zeros(l, l) for i in 1:length(var)];
    for k in 1:length(var)
        M = [get(S[i].terms, var[k], zero(Number)) for i in eachindex(S)]
        A[k] = Symmetric(M)
    end
    return A;
end
# Construct the vector of moment coefficients associated to the objective function
function build_c(M)
    var = all_variables(M.model)
    obj = objective_function(M.model).terms
    c = [get(obj, var[i], zero(Number)) for i in eachindex(var)]
    return c
end
# Create the linear constraints associated with equations 
function affine_constraints(M)
    aff = all_constraints(M.model, AffExpr, MathOptInterface.EqualTo{Float64});
    l = length(aff)
    var = all_variables(M.model)
    eq = [zeros(length(var)+1) for i in 1:l-1]
    for i in 2:l
        for k in 1:length(var)
            temp = constraint_object(aff[i]).func.terms
            if var[k] in temp.keys
                eq[i-1][k] = temp[var[k]]
            end
        end
    end
    return eq
end
#-----------------------
# Function that outputs the Lasserre SDP relaxation at order d of the PMO Polynomial model pmo_model_poly, in the format of a PMO SDP model.
function poly_to_sdp(pmo_model_poly, d)
    # Create the MomentTools Model from the PMO model
    M = create_model(vec(pmo_model_poly), variables(pmo_model_poly),d)
    # Construct the block diagonal PSD matrix associated to this semidefinite relaxations from the inequalities in the model
    A = (PSD_matrices(M), ">=0")
    # Construct the affine constraints from the equations in the model
    temp = affine_constraints(M)
    aff = [(temp[i], "=0") for i in 1:length(temp)]
    # Construct the vector associated with the objective function
    c = build_c(M)
    # Construct the unit mass constraint y_0 = 1
    y0 = [0 for i in 1:length(c)+1]
    y0[1] = 1
    y0[length(c)+1] = -1;
    # Create the PMO SDP model
    pmo_model_sdp = PMO.sdp((c, "inf"),
                 (y0, "=0"),
                 aff...,
                 A
                 )
    return pmo_model_sdp
end