"""
    Ai2

Ai2 performs over-approximated reachability analysis to compute the over-approximated output reachable set for a network.

# Problem requirement
1. Network: any depth, ReLU activation (more activations to be supported in the future)
2. Input: HPolytope
3. Output: HPolytope

# Return
`ReachabilityResult`

# Method
Reachability analysis using split and join.

# Property
Sound but not complete.

# Reference
T. Gehr, M. Mirman, D. Drashsler-Cohen, P. Tsankov, S. Chaudhuri, and M. Vechev,
"Ai2: Safety and Robustness Certification of Neural Networks with Abstract Interpretation,"
in *2018 IEEE Symposium on Security and Privacy (SP)*, 2018.
"""
struct Ai2 end

function solve(solver::Ai2, problem::Problem)
    reach = forward_network(solver, problem.network, problem.input)
    return check_inclusion(reach, problem.output)
end

forward_layer(solver::Ai2, layer::Layer, inputs::Vector{<:AbstractPolytope}) = forward_layer.(solver, layer, inputs)

function forward_layer(solver::Ai2, layer::Layer, input::AbstractPolytope)
    W, b, act = layer.weights, layer.bias, layer.activation
    outLinear = shiftcenter(linear_map(W, input), b)
    return transform(act, outLinear)
end

function transform(f::ReLU, P::AbstractPolytope)
    polys = VPolytope[]
    # check if 1:2^n relus is tighter range than relu(relu(...to the n))
    for i in dim(P)
        pos = meet(P, i, true)
        neg = meet(P, i, false)
        relu_neg = VPolytope([f(v) for v in vertices_list(neg)]) #dimensional relu

        push!(polys, tovrep(pos))
        push!(polys, relu_neg)
    end

    hull = polys[1]
    for P in polys[2:end]
        hull = convex_hull(hull, P)
    end

    return hull
end

# constraints are added in H-representation
meet(V::VPolytope, pos::Bool) = meet(tohrep(V), pos)
function meet(HP::HPolytope{T}, pos::Bool) where T
    H = copy(HP)
    # constraints are given by ax <= b so (-) is required for a positive constraint
    if (pos)  d = Matrix(-1.0I, dim(H), dim(H))
    else      d = Matrix(1.0I, dim(H), dim(H))
    end

    for i in size(d, 1)
        new_hs = LazySets.HalfSpace(d[i, :], zero(T))
        addconstraint!(H, new_hs)
    end
end



shiftcenter(zono::Zonotope, shift::Vector)         = Zonotope(zono.center + shift, zono.generators)
shiftcenter(poly::AbstractPolytope, shift::Vector) = shiftcenter(tovrep(poly), shift)

function shiftcenter(V::VPolytope, shift::Vector)
    shifted = [v + shift for v in vertices_list(V)]
    return VPolytope(shifted)
end

#=
meet and join will still become necessary in the zonotope case
The Case type is probably not necessary for correct dispatch
=#
# function meet(case::Case, H::HPolytope)
#     addconstraint!(H, constraint(case, H))
#     return H
# end

# function constraint(case::Type{Case}, n_dims, constraint_dim)
#     space = zeros(n_dims)
#     if case == Pos
#         space[constraint_dim] =  1.0
#     elseif case == Neg
#         space[constraint_dim] = -1.0
#     end
#     return HalfSpace(space, 0.0)
# end

# constraint(case::Case, poly::AbstractPolytope) = constraint(typeof(case), dim((poly), case.i)
