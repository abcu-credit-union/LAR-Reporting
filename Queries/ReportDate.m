let
    Source = Excel.CurrentWorkbook(){[Name="Table8"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Date", type date}})
in
    #"Changed Type"
