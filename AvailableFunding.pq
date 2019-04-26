let
BBSource = Table.AddColumn(
     Oracle.Database("BCUDatabase", [Query = ""&AvailableFundingSQL&""]),
"Source DB", each "Beaumont"),
  
CCSource = Table.AddColumn(
     Oracle.Database("RCCUDatabase", [Query = ""&AvailableFundingSQL&""]),
"Source DB", each "City Centre"),

ABCUSource = Table.Combine({BBSource, CCSource}),
    
//Account balances are added from the SubAcctBalances query.  These balances are what DNA considers principal only balances
    #"Added Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(ABCUSource, {"SOURCE", "ACCTNBR", "SUBACCTNBR"}, SubAcctBalances, {"SOURCE", "ACCTNBR", "SUBACCTNBR"}, "Balances", JoinKind.LeftOuter),
    "Balances", {"BALAMT"}),

//Currency information is pulled on an account level.  
//After USD and CAD balances have been identified this code translates USD to CAD using the month end FX rate
   #"Converted USD to CAD" = Table.AddColumn(
        Table.ExpandTableColumn(
            Table.NestedJoin(#"Added Balances", {"EFFDATE"}, FXRates, {"Date"}, "FX Rates", JoinKind.LeftOuter),
        "FX Rates", {"Rate"}),
    "Adj BALAMT", each if [CURRENCYCD] = "USD" then
        [BALAMT] * [Rate]
    else
        [BALAMT]),

//This is a basic if statement that checks the remaining maturity on the deposit to determine what line number it should be reported on
    #"Added Line Number" = Table.AddColumn(#"Converted USD to CAD", "Line Number", each if [REMAININGAMORTIZATION] = null then
        2701
    else if [REMAININGAMORTIZATION] < 12 then
        2703
    else if [REMAININGAMORTIZATION] >= 12 then
        2705
    else
        9999),

//This aggregates the values for reporting purposes
    #"Grouped Rows" = Table.Group(#"Added Line Number", {"EFFDATE", "Line Number"}, {{"FP BALANCE", each List.Sum([Adj BALAMT]), type number}})
in
    #"Grouped Rows"
