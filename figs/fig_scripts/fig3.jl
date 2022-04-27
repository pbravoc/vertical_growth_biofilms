using DataFrames, CSV
using Statistics, NaNMath
using Plots, StatsPlots, ColorSchemes, Colors
using LsqFit
using Plots.Measures

function get_average(df, strain_name)
    tf = filter(x->x.strain .== strain_name,df)
    l = Int(size(tf)[1]/3)
    h = reshape(tf.avg_height, (l, 3))
    h_avg = reduce(vcat, mean(h, dims=2))
    h_std = reduce(vcat, std(h, dims=2))
    t = tf.time[l+1:2*l]
    scatter!(t, h_avg, ribbon=h_std, 
             fillalpha=0.1, alpha=0.8, 
             markersize=3)
end

function smooth_heights(y, x, dt)
    model(x, p) = p[1] .+ p[2]*x # Linear model
    y_smooth = zeros(size(y))
    slope_mean = zeros(size(y))
    slope_error = zeros(size(y))
    y_smooth .= NaN              # Start them as NaNs and then fill
    slope_mean .= NaN
    slope_error .= NaN
    if size(df)[1] > 2           # If we have more points!
        for i=1:length(x)
            idx = (x .> x[i]-dt/2) .&& (x .< x[i]+dt/2)
            x_c, y_c = x[idx], y[idx]
            p_guess = [y_c[1], (y_c[end]-y_c[1])/(x_c[end]-x_c[1])]
            fit = curve_fit(model, x_c, y_c, p_guess)
            y_smooth[i] = model(x[i], fit.param)
            slope_mean[i] = fit.param[2]
            slope_error[i] = sqrt(estimate_covar(fit)[2,2])
        end
    end
    return y_smooth, slope_mean, slope_error
end

# Unbounded parameters fitting and simulation
Df =  DataFrame(CSV.File("data/timelapses/database.csv"))
df = filter(x->x.strain .== "bgt127" && 
               x.time .<= 48 && x.replicate =="A", Df)
pf = DataFrame(CSV.File("data/sims/f3a_heights_bounded.csv"))
#pf = DataFrame(CSV.File("data/sims/f3a_heights_unbounded.csv"))

myc = [ColorSchemes.gray1[1], ColorSchemes.okabe_ito[1],
                 ColorSchemes.okabe_ito[2], ColorSchemes.okabe_ito[3]] #okabe&ito(2002)
##
p1 = @df pf scatter(:time, :data, yerr=:data_error, markersize=2, color=myc[1],
               legend=:bottomright, label="Data")
@df pf plot!(:time, :nutrient_n, color=myc[4], linewidth=2, label="Nutrient")
@df pf plot!(:time, :logistic_n, color=myc[3], linewidth=2, label="Logistic (n)")
@df pf plot!(:time, :interface_n, color=myc[2], linewidth=2, label="Interface (n)")
@df pf plot!(:time, :logistic, color=myc[3], linestyle=:dash, linewidth=2, label="Logistic")
@df pf plot!(:time, :interface, color=myc[2], linestyle=:dash, linewidth=2, label="Interface")
plot!(xlabel="Time [hr]", ylabel="Height [μm]", grid=false, size=(500, 400), dpi=300)
#savefig("figs/fig3/a_unboundedfit.svg")

p2 = @df pf plot(:time, :data - :data, color=myc[1], linestyle=:dash, ribbon=:data_error, fillalpha=0.2, label=false)

@df pf plot!(:time, :nutrient_n - :data, color=myc[4], linewidth=2, label="Nutrient_n")
@df pf plot!(:time, :logistic_n- :data, color=myc[3], linewidth=2, label="Logistic_n")
@df pf plot!(:time, :interface_n- :data, color=myc[2], linewidth=2, label="Interface_n")
@df pf plot!(:time, :logistic- :data, color=myc[3], linestyle=:dash, linewidth=2, label="Nutrient")
@df pf plot!(:time, :interface- :data, color=myc[2], linestyle=:dash, linewidth=2, label="Interface")
plot!(xlabel="Time [hr]", ylabel="Residual [μm]", legend=false)

#plot!(inset = (1, bbox(0.35, 0.6, 0.3, 0.35)), subplot=2)
#@df pf scatter!(:data, :nutrient_n, color=3, markersize=2, markerstrokecolor=:auto, label="nutrient_n", subplot=2)
#@df pf scatter!(:data, :logistic, color=2, linestyle=:dash, markersize=2, markerstrokecolor=:auto, label="Logistic", subplot=2)
#@df pf scatter!(:data, :interface, color=1, linestyle=:dash, markersize=2, markerstrokecolor=:auto, label="Interface", subplot=2)
#@df pf plot!([0.0, 200.0], [0.0, 200.0], color=:black, alpha=0.5, linestyle=:dash, linewidth=2,legend=false, subplot=2)
#plot!(xticks=[], yticks=[], subplot=2)
#
function plot_slope(y, x, dt, c, l)
    smooth, slope, slope_error = smooth_heights(y, x, dt)
    plot!(y, slope, ribbon=slope_error, color=c, label=l)
end

dt = 4.0
h, dh, dh_e = smooth_heights(pf.data, pf.time, dt)
p3 = plot(xlabel="Height [μm]", ylabel="Δ Height [μm/hr]")
scatter!(h, dh, xerror=pf.data_error, yerror=dh_e, color=:black, alpha=0.75,
         markersize=2, label=false)
#vline!([h[findmax(dh)[2]]], color=:black, linestyle=:dash, label=false)
#hline!([0.0], color=:black, linestyle=:dash, label=false, legend=:right)
plot_slope(pf.interface, pf.time, dt, myc[2], "I")
plot_slope(pf.nutrient_n, pf.time, dt, myc[4], "N (n)")
plot_slope(pf.logistic_n, pf.time, dt, myc[3], "L (n)")
#plot!([500.0, 510.0], [[1,1], [2,2], [3,3]], color=[1 2 3], label=["a" "b" "c"])
plot!(xlim=(-1, 220.0), ylim=(-0.1, 13.0), legend=false)
#savefig("figs/figs_temp/fig3_c.svg")

l = @layout [
    a{0.5w} [b{0.5h}  
             c{0.5h}] 
]
plot(p1, p2, p3, size=(900, 350), layout=l, bottom_margin=4mm, left_margin=3mm, grid=false)
savefig("figs/fig3/fig3.pdf")
