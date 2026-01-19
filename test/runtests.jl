using IFXFiles
using Test
using DataFrames

@testset "IFXFiles.jl" begin
    @testset "Basic functionality with file" begin
        # Create temporary test file
        testfile = tempname()
        write(
            testfile,
            """
            Author=John Doe
            Date=2024-01-15
            Columns=Col1,Col2,Col3

            [Data]
            1.0 2.0 3.0
            4.0 5.0 6.0
            7.0 8.0 9.0
            """
        )

        try
            df = IFXFiles.read(testfile)

            # Test DataFrame structure
            @test size(df) == (3, 3)
            @test names(df) == ["Col1", "Col2", "Col3"]

            # Test data values
            @test df.Col1 == [1.0, 4.0, 7.0]
            @test df.Col2 == [2.0, 5.0, 8.0]
            @test df.Col3 == [3.0, 6.0, 9.0]

            # Test metadata
            @test metadata(df, "Author") == "John Doe"
            @test metadata(df, "Date") == "2024-01-15"
            @test metadata(df, "Columns") == "Col1,Col2,Col3"
        finally
            rm(testfile, force=true)
        end
    end

    @testset "Reading from IOBuffer" begin
        io = IOBuffer("""
            Version=1.0
            Units=meters
            Columns=X,Y,Z

            [Data]
            10 20 30
            40 50 60
            """)

        df = IFXFiles.read(io)

        @test size(df) == (2, 3)
        @test names(df) == ["X", "Y", "Z"]
        @test df.X == [10, 40]

        @test metadata(df, "Version") == "1.0"
        @test metadata(df, "Units") == "meters"
    end

    @testset "Empty lines in header" begin
        io = IOBuffer("""
            Key1=Value1


            Key2=Value2

            Columns=A,B

            [Data]
            1 2
            3 4
            """)

        df = IFXFiles.read(io)

        @test size(df) == (2, 2)
        @test names(df) == ["A", "B"]

        @test metadata(df, "Key1") == "Value1"
        @test metadata(df, "Key2") == "Value2"
    end

    @testset "Metadata with spaces and special characters" begin
        io = IOBuffer("""
            Description=This is a test file
            Path=/home/user/data.txt
            Threshold=1.5e-3
            Columns=Time,Value,Status

            [Data]
            0.0 100.5 1
            0.1 101.2 1
            """)

        df = IFXFiles.read(io)

        @test metadata(df, "Description") == "This is a test file"
        @test metadata(df, "Path") == "/home/user/data.txt"
        @test metadata(df, "Threshold") == "1.5e-3"
    end

    @testset "Integer and floating point data" begin
        io = IOBuffer("""
            Type=Mixed
            Columns=Int,Float,Sci

            [Data]
            1 2.5 1.5e-3
            2 3.7 2.1e-3
            3 4.2 3.8e-3
            """)

        df = IFXFiles.read(io)

        @test size(df) == (3, 3)
        @test df.Int == [1, 2, 3]
        @test df.Float ≈ [2.5, 3.7, 4.2]
        @test df.Sci ≈ [1.5e-3, 2.1e-3, 3.8e-3]
    end

    @testset "Single column data" begin
        io = IOBuffer("""
            Name=SingleColumn
            Columns=Value

            [Data]
            10
            20
            30
            """)

        df = IFXFiles.read(io)

        @test size(df) == (3, 1)
        @test names(df) == ["Value"]
        @test df.Value == [10, 20, 30]
    end

    @testset "Single row data" begin
        io = IOBuffer("""
            Test=SingleRow
            Columns=A,B,C,D

            [Data]
            1 2 3 4
            """)

        df = IFXFiles.read(io)

        @test size(df) == (1, 4)
        @test names(df) == ["A", "B", "C", "D"]
        @test df[1, :] == [1, 2, 3, 4]
    end

    @testset "Multiple spaces as delimiter" begin
        io = IOBuffer("""
            Format=Whitespace
            Columns=Col1,Col2,Col3

            [Data]
            1    2    3
            4    5    6
            """)

        df = IFXFiles.read(io)

        @test size(df) == (2, 3)
        @test df.Col1 == [1, 4]
        @test df.Col2 == [2, 5]
        @test df.Col3 == [3, 6]
    end

    @testset "Metadata with equals sign in value" begin
        io = IOBuffer("""
            Equation=E=mc^2
            Formula=a=b+c
            Columns=X,Y

            [Data]
            1 2
            3 4
            """)

        df = IFXFiles.read(io)

        @test metadata(df, "Equation") == "E=mc^2"
        @test metadata(df, "Formula") == "a=b+c"
    end

    @testset "No metadata, only Columns" begin
        io = IOBuffer("""
            Columns=First,Second

            [Data]
            100 200
            300 400
            """)

        df = IFXFiles.read(io)

        @test size(df) == (2, 2)
        @test names(df) == ["First", "Second"]

        meta_keys = keys(metadata(df))
        @test length(meta_keys) == 1
        @test metadata(df, "Columns") == "First,Second"
    end

    @testset "Trailing whitespace in data" begin
        io = IOBuffer("""
            Test=TrailingSpace
            Columns=A,B,C

            [Data]
            1 2 3   
            4 5 6   
            """)

        df = IFXFiles.read(io)

        @test size(df) == (2, 3)
        @test df.C == [3, 6]
    end

    @testset "Empty data section" begin
        io = IOBuffer("""
            Empty=True
            Columns=X,Y

            [Data]
            """)

        df = IFXFiles.read(io)

        @test size(df) == (0, 2)
        @test names(df) == ["X", "Y"]
        @test isempty(df)
    end

    @testset "Column count validation" begin
        io = IOBuffer("""
            Columns=A,B,C

            [Data]
            1 2 3
            4 5 6
            """)

        df = IFXFiles.read(io)

        # Verify column count matches Columns specification
        @test ncol(df) == 3
        @test ncol(df) == length(split(metadata(df, "Columns"), ","))
    end

    @testset "All metadata keys present" begin
        io = IOBuffer("""
            Key1=Value1
            Key2=Value2
            Key3=Value3
            Columns=A,B

            [Data]
            1 2
            """)

        df = IFXFiles.read(io)

        meta_keys = collect(keys(metadata(df)))
        @test "Key1" in meta_keys
        @test "Key2" in meta_keys
        @test "Key3" in meta_keys
        @test "Columns" in meta_keys
        @test length(meta_keys) == 4
    end

end
