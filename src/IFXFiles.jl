"""
IFXFiles

A module for reading IFX file format data into DataFrames.

IFX files are structured text files containing a metadata header section followed
by space-delimited tabular data. The header section contains key-value pairs and
ends with a `[Data]` marker. Column names are specified in the header using the
`Columns=` key.

# File Format
The IFX file format consists of:
- Header section with `key=value` pairs (one per line)
- A required `Columns=col1,col2,col3` line specifying column names
- A `[Data]` marker indicating the end of the header
- Space-delimited data rows (comments starting with `#` are ignored)

# Example
```julia
using IFXFiles

# Read from file
df = IFXFiles.read("data.ifx")

# Access metadata
colmeta(df, :note)

# Read from IO stream
open("data.ifx") do io
    df = IFXFiles.read(io)
end
```

# Exports
- `read`: Read IFX files into DataFrames with metadata
"""
module IFXFiles

using CSV, DataFrames

"""
    read(stream::IO)::DataFrame
    read(filepath::AbstractString)::DataFrame

Read IFX format data and return a DataFrame with metadata.

This function parses the header section to extract metadata as key-value pairs,
identifies column names from the `Columns=` header line, then reads the 
space-delimited data section into a DataFrame. All metadata is attached to the
returned DataFrame as metadata with `:note` style.

# Arguments
- `stream::IO`: An open IO stream positioned at the beginning of an IFX file
- `filepath::AbstractString`: Path to an IFX file to read

# Returns
- `DataFrame`: A DataFrame containing the parsed data with metadata attached

# Throws
- `ErrorException`: If the header is malformed, `Columns=` line is missing, or no data is present
- `SystemError`: If the file cannot be opened (filepath method only)

# Examples
```julia
# Read from file path
df = IFXFiles.read("measurement.ifx")

# Read from IO stream
open("measurement.ifx") do io
    df = IFXFiles.read(io)
end

# Access metadata
measurement_type = colmeta(df, :note)["MeasurementType"]
```
"""
function read(stream::IO)::DataFrame
    metadata = Dict{String,String}()

    # Read header section into metadata dictionary
    for line in eachline(stream)
        stripped = strip(line)

        # Skip empty lines
        if isempty(stripped)
            continue
        # [Data] marker signals end of header section
        elseif startswith(stripped, "[Data]")
            break
        else
            # Parse key=value pairs
            key_val_tuple = split(stripped, "=", limit=2, keepempty=true)
            if length(key_val_tuple) < 2
                error("Invalid line in the header")
            end
            push!(metadata, Pair(key_val_tuple...))
        end
    end

    # Extract column names from metadata
    if haskey(metadata, "Columns")
        column_names = String.(strip.(split(metadata["Columns"], ',')))
    else
        error("No Columns= line in the header")
    end

    # Verify data section exists
    if eof(stream)
        error("There is no data")
    end

    # Read the CSV data section with space delimiter
    df = CSV.read(
        stream,
        DataFrame;
        delim=' ',
        ignorerepeated=true, # Handle multiple consecutive spaces
        header=column_names,
        comment="#" # Ignore comment lines
    )

    # Attach metadata to the DataFrame
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
