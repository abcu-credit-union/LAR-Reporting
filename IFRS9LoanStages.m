let
    StartDate = Date.ToText(ReportDate[Date]{0}, "YYYYMMDD"),
    Source = Csv.Document(File.Contents("O:\Liquidity Adequacy Reporting\IFRS9 Loan Stages\"&StartDate&" ABCU Loan Stages.csv"),
        [Delimiter=",", Columns=4, Encoding=1252, QuoteStyle=QuoteStyle.None]),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Removed Top Rows" = Table.Skip(#"Promoted Headers",1),

    #"Transformed Branch Number" = Table.TransformColumns(#"Removed Top Rows", 
        {{"Branch Number", each if _ <> "3769899" then "RCCU" else "BCU"}}),

    #"Added Source DB" = Table.AddColumn(#"Transformed Branch Number", "Source DB", each if [Branch Number] = "RCCU" then
        "City Centre"
    else "Beaumont", type text),

    #"Renamed Columns" = Table.RenameColumns(#"Added Source DB",
        {{"Branch Number", "Source"}, 
        {"Grouping", "Account Number"}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns",
        {{"Account Number", type number}, 
        {"Stage", type number}, 
        {"Final Loan ECL", Currency.Type}}),

    #"Removed Errors" = Table.RemoveRowsWithErrors(#"Changed Type", {"Account Number"}),
    #"Removed Errors1" = Table.RemoveRowsWithErrors(#"Removed Errors", {"Final Loan ECL"})
in
    #"Removed Errors1"
