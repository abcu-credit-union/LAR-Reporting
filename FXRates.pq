let
    Source = Excel.CurrentWorkbook(){[Name="Table7"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Date", type datetime}, {"Rate", type number}}),
    #"Removed Blank Rows" = Table.SelectRows(#"Changed Type", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null})))
in
    #"Removed Blank Rows"