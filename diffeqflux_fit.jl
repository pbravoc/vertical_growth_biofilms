using DifferentialEquations, DiffEqFlux, Plots
using DataFrames, CSV

G(z, zstar) = z < zstar ? z : zstar 

function interface_limited(du, u, p, t)
    h = u[1] 
    α, β, hstar = p
    du[1] = α*G.(h, hstar) - β*h 
    return du
end

function flux_fit(time_data, x_data, p)
    u0 = x_data[1]  
    prob = ODEProblem(interface_limited, [u0], (0.0, 50.0), p) # Set the problem
    function loss(p)
        sol = solve(prob, Tsit5(), p=p, saveat=time_data) # Force time savings to match data
        sol_array = reduce(vcat, sol.u)
        loss = sum(abs2, sol_array .- x_data)
        return loss, sol
    end
    result_ode = DiffEqFlux.sciml_train(loss, p,
                                        maxiters=100)
    return result_ode.u
end

df = DataFrame(CSV.File("data/timelapses/database.csv"))
df.avg_height = abs.(df.avg_height)                      # Remove negative nums
## Load data 
my_strain, my_replicate = "BGT127", "C"
tf =  filter(row -> row.Replicate .== my_replicate && 
             row.Strain .== my_strain, df);
p = [1.0, 0.05, 15.0]
mlfit = flux_fit(tf.Time, tf.avg_height, p)
probML = ODEProblem(interface_limited, [tf.avg_height[1]], (0.0, 50.0), mlfit) # Set the problem
solML = solve(probML, saveat=tf.Time)
h_pred = round(mlfit[1]*mlfit[3]/mlfit[2], digits=1)
scatter(tf.Time, tf.avg_height, label="Experimental Data", legend=:topleft, 
        grid=false, title=string(my_strain, my_replicate))
plot!(solML, color=:black, linewidth=2, xlabel="Time (hr)", label=string("Fit, h_max =", h_pred))
##
