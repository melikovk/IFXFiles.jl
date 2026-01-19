# IFXFiles

A module for reading IFX file format data into DataFrames.

IFX files are structured text files containing a metadata header section followed
by space-delimited tabular data. The header section contains key-value pairs and
ends with a `[Data]` marker. Column names are specified in the header using the
`Columns=` key.

### File Format
The IFX file format consists of:
- Header section with `key=value` pairs (one per line)
- A required `Columns=col1,col2,col3` line specifying column names
- A `[Data]` marker indicating the end of the header
- Space-delimited data rows (comments starting with `#` are ignored)