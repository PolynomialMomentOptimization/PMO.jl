#= 
 Generates symmetric homogeneous polynomials in n variables, which are 
 Positive Semi Definite but not Sums of Squares.

 Written by Sebatsian Dubus

=#

using DynamicPolynomials

FCT["sym"] = function(n::Int64)
    
    @polyvar X[1:n]

    p1 = sum(X[i] for i = 1 : n)
    p2 = sum(X[i]^2 for i = 1 : n)
    p3 = sum(X[i]^3 for i = 1 : n)
    p4 = sum(X[i]^4 for i = 1 : n)
    
    sym4  = 4*p1^4-5*p2*p1^2-139//20*p3*p1+4*p2^2+4*p4
    
    Sym4  = PMO.polynomial((sym4,"inf"))

    Sym4["doc"]=
    """
    Acevedo, Blekherman, Debus and Riener found this symmetric quartic
    "limit" form. It is non-negative in any number of variables and not a sum of
    squares already in the minimal case of n=4.
    """
    Sym4[:name] = "SymmetricPSDnotSOS"*string(n)
    Sym4[:author] = "Sebastian Debus"

    return Sym4 

end
