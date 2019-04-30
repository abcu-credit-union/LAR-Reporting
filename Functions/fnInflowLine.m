// fnInflowLine
let
    fnInflowLine = (MJACCTTYPCD, CURRMIACCTTYPCD, PERSNBR, ORGNBR) =>
        let 
            ConsIndet = Table.Column(Excel.CurrentWorkbook(){[Name="CnsInd"]}[Content], "Consumer Indeterminate"),
            CommIndet = Table.Column(Excel.CurrentWorkbook(){[Name="ComInd"]}[Content], "Commercial Indeterminate"),
            CommDet = Table.Column(Excel.CurrentWorkbook(){[Name="ComDet"]}[Content], "Commercial Determinate"),
            CommMtg = Table.Column(Excel.CurrentWorkbook(){[Name="ComMtg"]}[Content], "Commercial Mortgage"),
            
            lineNum = if PERSNBR <> null and List.Contains({"CK", "SAV"}, MJACCTTYPCD) or List.Contains(ConsIndet, CURRMIACCTTYPCD) then
                2823
            else if ORGNBR <> null and List.Contains({"CK", "SAV"}, MJACCTTYPCD) or List.Contains(CommIndet, CURRMIACCTTYPCD) then
                2831
            else if List.Contains({"LOCM", "MRLO"}, CURRMIACCTTYPCD) then
                2824
            else if MJACCTTYPCD = "MTG" then
                2825
            else if MJACCTTYPCD = "CNS" then
                2822
            else if List.Contains(CommDet, CURRMIACCTTYPCD) then
                2828
            else if List.Contains(CommMtg, CURRMIACCTTYPCD) then
                2832
            else
                9999
        in
            lineNum
in
    fnInflowLine
