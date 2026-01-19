module IFXFiles

function read(stream::IO)::DataFrame
    metadata = Dict{String,String}()
    # read header into metadata dictionary
    for line in eachline(stream)
        stripped = strip(line)
        if isempty(stripped)
            continue
        elseif startswith(stripped, "[Data]")
            break # [Data] markers end the header section
        else
            push!(metadata, Pair(split(stripped, "=", limit=2, keepempty=true)...))
        end
    end

    if haskey(metadata, "Columns")
        column_names = String.(strip.(split(metadata["Columns"], ',')))
    else
        error("Could not find Columns= line in header")
    end

    # Read the CSV starting from the data section
    df = CSV.read(
        stream,
        DataFrame;
        delim=' ',
        ignorerepeated=true,  # Handle multiple spaces
        header=column_names,
        comment="#"
    )
    # Add metadata to the Dataframe
    for (key, value) in metadata
        metadata!(df, key, value, style=:note)
    end
    return df
end

function read(filepath::AbstractString)
    open(filepath, "r") do file
        read(file)
    end
end

end
