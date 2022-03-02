using DataFrames, CSV, CircularArrays
using Statistics, NaNMath
using Plots, StatsPlots
using DifferentialEquations, DiffEqFlux

function block_bootstrap(df, n_blocks, block_size)
    indices = CircularArray(1:size(df)[1]-1)
    sample_start = sample(indices, n_blocks)
    sample_temp = reduce(vcat, 
                    [Array(x:x+block_size) for x in sample_start])
    si = [(x % size(df)[1])+1 for x in sample_temp]
    return df[si,:]  
end
G(z, zstar) = z < zstar ? z : zstar 
function interface(du, u, p, t)
    h = u[1] 
    α, β, hstar = p
    du[1] = α*G.(h, hstar) - β*h 
    return du
end
function logistic(du, u , p, t)
    h = u[1]
    α, K_h = p  
    du[1] = α*h*(1- h/(K_h))
    return du 
end
function fit_data(t_data, h_data)
    idxs = sortperm(t_data)  # Sort time indexes
    t_data, h_data = t_data[idxs], h_data[idxs]
    result_ode = [NaN, NaN, NaN]
    try
        u0 = [0.2]
        pguess = [0.8, 300.0]
        prob = ODEProblem(logistic, u0, (0.0, t_data[end]), pguess)
        function loss(p)
            sol = solve(prob, Tsit5(), p=p, saveat=t_data, save_idxs=1) # Force time savings to match data
            sol_array = reduce(vcat, sol.u)
            loss = sum(abs2, sol_array .- h_data)
            return loss, sol
        end
        result_ode = DiffEqFlux.sciml_train(loss, pguess,  
                                            lower_bounds = [0.0, 0.0], 
                                            upper_bounds = [2.0, 1000.0])
    catch e 
        #print("didnt converge")
    end
    return result_ode
end 
Df =  DataFrame(CSV.File("data/timelapses/database.csv"))
df = filter(x-> x.strain .== "bgt127", Df)
@df df scatter(:time, :avg_height, group=(:replicate), legend=false)
##
params = fit_data(df.time, df.avg_height)
##
bgt127params = params
prob = ODEProblem(logistic, [0.2], (0.0, 350.0), params)
sol = solve(prob, saveat=0.5, save_idxs=1)
@df df scatter(:time, :avg_height, group=(:replicate), legend=false)
plot!(sol, linewidth=2, color=:black)

##
param_matrix = reduce(hcat, [bgt127params.u, jt305params.u, gob33params.u])
all_params = DataFrame("Name"=>["bgt127", "jt305", "gob33"], 
                       "α"=>param_matrix[1,:], "K"=>param_matrix[2,:])
##
CSV.write("data/sims/allpointsol_log.csv", all_params)

##
all_params = DataFrame("t"=>sol.t, 
                       "bgt127"=>bgt127sol, "jt305"=>jt305sol,
                       "gob33"=>gob33sol)
CSV.write("data/sims/allpointsol.csv", all_params)
##
plot(all_params.t, all_params.jt305)