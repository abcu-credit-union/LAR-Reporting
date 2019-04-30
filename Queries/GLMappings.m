let
    Source = Excel.CurrentWorkbook(){[Name="Table3"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"FR2900 Code", type text}})
in
    #"Changed Type"
