using DataFrames, NPZ 
using Arrow
using NaNMath

"""
Takes a dictionary as input, and outputs a 
DataFrame containing profiles and some
simple metrics
"""
function add_to_database(df, dict)
    times = npzread(string(dict["folder"], "times.npy"))
    replicate = ["A", "B", "C", "D", "E", "F", "G", "H", "I"] # Improve this

    # Main (timelapse) points
    for i=1:3
        profile = npzread(string(dict["folder"], "profiles_",    
                          replicate[i],".npy"))
        for j=1:size(times)[2]
            rowdata = (dict["strain"], dict["date"], replicate[i], times[i,j], j,
                       dict["zoom"], dict["by"], profile[j,:])
            push!(df, rowdata)
        end
    end

    # Secondary (control) points 
    control_times = npzread(string(dict["folder"], "times_control.npy"))
    control_profiles = npzread(string(dict["folder"], "profiles_control.npy"))
    for i=1:size(control_times)[1]
        zoom = i < 4 ? 50 : 10           # ABCDEF are 50x, GHI are 10x due to size
        rowdata = (dict["strain"], dict["date"], replicate[i+3], control_times[i], i,
        zoom, dict["by"], control_profiles[i,:])
        push!(df, rowdata)
    end
    print(string("Added" , dict["strain"]))
end

# Initialize an empty database
df = DataFrame(Strain = String[], Date = String[], Replicate = String[], 
               Time = Float32[], Order=Int32[], Zoom = Float32[], 
               By = String[], Profile = Array[]);
print("Columns created")

# Add Vibrios
Df = DataFrame(Arrow.Table("/home/pablo/Biofilms/Data/radialv2.arrow"));
tf = select(Df, :Strain, :Date, :Replicate, :Time, :Order, :Zoom, :By, :Profile);
for i=1:size(tf)[1]
    push!(df, tf[i,:])
end
print("Added older vcholerae data")

# Dictionaries for each strain 
# BGT127: Aeromonas
bgt127 = Dict("folder" => "data/timelapses/2021-06-25_bgt127/",
              "strain" => "BGT127", "date" => "2021-06-25", 
              "zoom" => 50, "by" => "pbravo")

# JT305: Ecoli
jt305 = Dict("folder" => "data/timelapses/2021-07-09_jt305/",
              "strain" => "JT305", "date" => "2021-07-09", 
              "zoom" => 50, "by" => "pbravo")

# Add metadata and profiles to database 
add_to_database(df, bgt127)
add_to_database(df, jt305)

# Simple calculations
df.mid_height = [df.Profile[i][Int(length(df.Profile[i])/2)] for i=1:size(df)[1]]
df.max_height = [NaNMath.maximum(df.Profile[i]) for i=1:size(df)[1]]
l = [findall(x->!isnan(x), y)[1] for y in df.Profile]
r = [findall(x->!isnan(x), y)[end] for y in df.Profile]
df.width = (r-l)* 0.17362 * 1e-3 * 50 ./ df.Zoom
#df.volume  
#df.std

# Complex calculations 
#df.Roughness 
#df.Fractal 
#df.Curvature

# Remove profiles from database to make it small
df = select(df, Not(:Profile))

# Write dataframe as an arrow file
Arrow.write("data/timelapses/profile_database.arrow", 
            df, compress = :zstd)
print("success!")