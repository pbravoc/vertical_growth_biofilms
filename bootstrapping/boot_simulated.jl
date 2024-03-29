using DataFrames, CSV, CircularArrays
using Statistics, NaNMath, StatsBase
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
function fit_data(t_data, h_data)
    idxs = sortperm(t_data)  # Sort time indexes
    t_data, h_data = t_data[idxs], h_data[idxs]
    u0 = [0.1]
    pguess = [0.8, 0.1, 15.0]
    prob = ODEProblem(interface, u0, (0.0, t_data[end]), pguess)
    function loss(p)
        sol = solve(prob, Tsit5(), p=p, saveat=t_data, save_idxs=1) # Force time savings to match data
        sol_array = reduce(vcat, sol.u)
        loss = sum(abs2, sol_array .- h_data)
        return loss, sol
    end 
    result_ode = DiffEqFlux.sciml_train(loss, pguess)#, 
                                        #lower_bounds = [1e-4, 1e-5, 1.0], 
                                        #upper_bounds = [10.0, 5.0, 1000.0])
    return result_ode
end 

function boot_fit2(df, n)
    p_bootstrap = []
    while length(p_bootstrap) < n
        Threads.@threads for i=1:n-length(p_bootstrap)
            boot_df = block_bootstrap(df, 20, 5)
            try
                asdf = fit_data(boot_df.t, boot_df.h)
                append!(p_bootstrap, [asdf.u])
            catch
            end
        end
    end
    return reduce(hcat, p_bootstrap)'
end
##
Df =  DataFrame(CSV.File("data/sims/simulated_data.csv"))
tf = filter(x-> x.S==100, Df)
@df tf scatter(:t, :h, group=:r, title="α=0.7, β=0.05, L=10.0", xlabel="Time [hr]", ylabel="Height[μm/hr]",
               legend=:topleft, size=(450, 400), markersize=4, dpi=400)
savefig("figs/bootstrapping/simulated_timelapse.png")

##
pf = DataFrame()
n = 128
for s in unique(Df.S)[101:end]
    print(s)
    tf = filter(x-> x.S==s, Df)
    pars = boot_fit2(tf, n)
    new_frame = DataFrame("S"=>repeat([s], n), "id"=>Array(1:n),
                          "α"=>pars[:,1], "β"=>pars[:,2], "L"=>pars[:,3])
    append!(pf, new_frame)
end
##
CSV.write("data/sims/sims_bootstrap_06.csv", pf)
##
Df = DataFrame()
for i in ["01", "02", "03", "04", "05", "06"]
    df =  DataFrame(CSV.File("data/sims/sims_bootstrap_"*i*".csv"))
    append!(Df, df)
end

@df Df scatter(:α, :β, :L, grouping=:S, markersize=1, markerstrokecolor=:auto,
               xlim=(0.15, 0.95), ylim=(0.0, 0.15), zlim=(0.0, 60.0), label=false,
               xlabel="Alpha [um/hr]", ylabel="Beta [um/hr]", zlabel="L [um]",
               size=(800, 600))

#savefig("figs/bootstrapping/scatter_sims.html")
##
@df Df scatter(:α, :β, grouping=:S, xlim=(0.15, 0.95), ylim=(0.0, 0.15))