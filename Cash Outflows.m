/*************************************************************************************************************************************************************************************************************************************************************/

let
    StartDate = Text.From(ReportDate[Date]{0}),   
    BCUSource = Oracle.Database("BCUDatabase", [Query=
        "SELECT
            'BCU' AS SOURCE, 
            ACCT.BRANCHORGNBR,
            WH_ACCTCOMMON.ACCTNBR,
            BalSubAcct.SUBACCTNBR, 
            WH_ACCTCOMMON.EFFDATE, 
            WH_ACCTCOMMON.MJACCTTYPCD, 
            WH_ACCTCOMMON.NOTEBAL, 
            WH_ACCTCOMMON.CURRACCTSTATCD, 
            WH_ACCTCOMMON.CURRMIACCTTYPCD,
            WH_ACCTCOMMON.PRODUCT,
            BalSubAcct.BALCATCD,
            BalSubAcct.BALTYPCD,
            MJMIACCTTYP.CURRENCYCD,
            COALESCE(CEIL(MONTHS_BETWEEN(ACCT.DATEMAT, TO_DATE('"&StartDate&"','MM/DD/YYYY'))), 0) AS RemainingAmortization,
            WH_ACCTCOMMON.TAXRPTFORPERSNBR,
            WH_ACCTCOMMON.TAXRPTFORORGNBR
        FROM WH_ACCTCOMMON
            LEFT OUTER JOIN 
                (SELECT
                    ACCTNBR,
                    SUBACCTNBR,
                    BALCATCD,
                    BALTYPCD
                FROM ACCTSUBACCT
                WHERE BALTYPCD = 'BAL'
                    AND BALCATCD = 'NOTE')
                BalSubAcct
                ON WH_ACCTCOMMON.ACCTNBR = BalSubAcct.ACCTNBR
            INNER JOIN ACCT
                ON WH_ACCTCOMMON.ACCTNBR = ACCT.ACCTNBR
            LEFT OUTER JOIN MJMIACCTTYP
                ON WH_ACCTCOMMON.MJACCTTYPCD = MJMIACCTTYP.MJACCTTYPCD
                AND WH_ACCTCOMMON.CURRMIACCTTYPCD = MJMIACCTTYP.MIACCTTYPCD          
        WHERE WH_ACCTCOMMON.EFFDATE = TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
            AND WH_ACCTCOMMON.NOTEBAL > 0
            AND WH_ACCTCOMMON.MJACCTTYPCD IN ('CK', 'SAV', 'TD')
            AND WH_ACCTCOMMON.CURRMIACCTTYPCD NOT IN ('ECSC', 'ECSM', 'FCSC', 'FCSM')
            AND (WH_ACCTCOMMON.TAXRPTFORORGNBR NOT IN (1402, 786)
                OR WH_ACCTCOMMON.TAXRPTFORORGNBR IS NULL)
            AND LOWER(WH_ACCTCOMMON.PRODUCT) NOT LIKE '%internal%'
    "]),
    RCCUSource = Oracle.Database("RCCUDatabase", [Query=
        "SELECT
            'RCCU' AS SOURCE,
            ACCT.BRANCHORGNBR, 
            WH_ACCTCOMMON.ACCTNBR,
            BalSubAcct.SUBACCTNBR, 
            WH_ACCTCOMMON.EFFDATE, 
            WH_ACCTCOMMON.MJACCTTYPCD, 
            WH_ACCTCOMMON.NOTEBAL, 
            WH_ACCTCOMMON.CURRACCTSTATCD, 
            WH_ACCTCOMMON.CURRMIACCTTYPCD,
            WH_ACCTCOMMON.PRODUCT,
            BalSubAcct.BALCATCD,
            BalSubAcct.BALTYPCD,
            MJMIACCTTYP.CURRENCYCD,
            COALESCE(CEIL(MONTHS_BETWEEN(ACCT.DATEMAT, TO_DATE('"&StartDate&"','MM/DD/YYYY'))), 0) AS RemainingAmortization,
            WH_ACCTCOMMON.TAXRPTFORPERSNBR,
            WH_ACCTCOMMON.TAXRPTFORORGNBR
        FROM WH_ACCTCOMMON
            LEFT OUTER JOIN 
                (SELECT
                    ACCTNBR,
                    SUBACCTNBR,
                    BALCATCD,
                    BALTYPCD
                FROM ACCTSUBACCT
                WHERE BALTYPCD = 'BAL'
                    AND BALCATCD = 'NOTE')
                BalSubAcct
                ON WH_ACCTCOMMON.ACCTNBR = BalSubAcct.ACCTNBR
            INNER JOIN ACCT
                ON WH_ACCTCOMMON.ACCTNBR = ACCT.ACCTNBR
            LEFT OUTER JOIN MJMIACCTTYP
                ON WH_ACCTCOMMON.MJACCTTYPCD = MJMIACCTTYP.MJACCTTYPCD
                AND WH_ACCTCOMMON.CURRMIACCTTYPCD = MJMIACCTTYP.MIACCTTYPCD           
        WHERE WH_ACCTCOMMON.EFFDATE = TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
            AND WH_ACCTCOMMON.NOTEBAL > 0
            AND WH_ACCTCOMMON.MJACCTTYPCD IN ('CK', 'SAV', 'TD')
            AND WH_ACCTCOMMON.CURRMIACCTTYPCD NOT IN ('ECSC', 'ECSM', 'FCSC', 'FCSM')
            AND LOWER(WH_ACCTCOMMON.PRODUCT) NOT LIKE '%internal%'
    "]),
    ABCUSource = Table.Combine({BCUSource, RCCUSource}),

    #"Added GL Numbers" = Table.ExpandTableColumn(
        Table.NestedJoin(ABCUSource, {"BRANCHORGNBR", "MJACCTTYPCD", "CURRMIACCTTYPCD", "BALCATCD", "BALTYPCD"}, DNAGLMapping, {"COSTCENTER", "MJACCTTYPCD", "MIACCTTYPCD", "BALCATCD", "BALTYPCD"}, "GL", JoinKind.LeftOuter),
    "GL", {"GLNUM", "GLACCTTITLENAME"}),
    #"Added GL Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added GL Numbers", {"BRANCHORGNBR", "GLNUM"}, FASQuery, {"OrgShortName", "UserAcctNum"}, "GL Balance", JoinKind.LeftOuter),
    "GL Balance", {"YTDBal"}),

//Account balances are added from the SubAcctBalances query.  These balances are what DNA considers principal only balances
    #"Added Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added GL Balances", {"SOURCE", "ACCTNBR", "SUBACCTNBR"}, SubAcctBalances, {"SOURCE", "ACCTNBR", "SUBACCTNBR"}, "Balances", JoinKind.LeftOuter),
    "Balances", {"BALAMT"}),
    #"Added Product Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added Balances", {"BRANCHORGNBR", "GLNUM"}, OutflowDNAProductBal, {"BRANCHORGNBR", "GLNUM"}, "ProductBal", JoinKind.LeftOuter),
    "ProductBal", {"Product Balance"}),


//Currency information is pulled on an account level.  After USD and CAD balances have been identified this code translates USD to CAD using the month end FX rate
   #"Add FX Rate" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added Product Balances", {"EFFDATE"}, FXRates, {"Date"}, "FX Rates", JoinKind.LeftOuter),
    "FX Rates", {"Rate"}),
   #"Converted USD to CAD" = Table.FromRecords(
        Table.TransformRows(#"Add FX Rate", (r) => Record.TransformFields(r,
            {{"BALAMT", each if r[CURRENCYCD] = "USD" then
                _ * r[Rate]
            else _},
            {"Product Balance", each if r[CURRENCYCD] = "USD" then
                _ * r[Rate]
            else _}}))),
    #"Added FP Balance" = Table.AddColumn(#"Converted USD to CAD", "FP BAL", each ([BALAMT]/[Product Balance]) * [YTDBal]),

//A function is called here that determines the line number using criteria set out in the F&S Completion Guidelines
    #"Added Line Num" = Table.AddColumn(#"Added FP Balance", "Line Num", each fnOutflowLine([MJACCTTYPCD], [CURRMIACCTTYPCD], [PRODUCT], [TAXRPTFORPERSNBR], [TAXRPTFORORGNBR])),
    #"Added Liquidity Bal" = Table.AddColumn(#"Added Line Num", "LIQUIDITY BAL", each [FP BAL]),
    
//This function creates the cash inflows, and outflows based on the criteria set out in the F&S completition guidelines. A record is produced with each outflow grouped into its respective bucket, the next line of code expands those records. 
    #"Added Outflows" = Table.ExpandRecordColumn(
        Table.AddColumn(#"Added Liquidity Bal", "Records", each fnPayments([Line Num], [LIQUIDITY BAL], [SUBACCTNBR], [REMAININGAMORTIZATION])),
    "Records", {"Month1", "Month2", "Month3", "Month4to6", "Month7to9", "Month10to12", "Month12Up"}),
    //Aggregates the results for reporting
    #"Grouped Rows" = Table.Group(#"Added Outflows", {"EFFDATE", "Line Num"}, 
        {{"FP BAL", each List.Sum([FP BAL]), type number}, 
        {"LIQUIDITY BAL", each List.Sum([LIQUIDITY BAL]), type number}, 
        {"MTH 1", each List.Sum([Month1]), type number}, 
        {"MTH 2", each List.Sum([Month2]), type number}, 
        {"MTH 3", each List.Sum([Month3]), type number}, 
        {"MTHS 4 TO 6", each List.Sum([Month4to6]), type number}, 
        {"MTHS 7 TO 9", each List.Sum([Month7to9]), type number}, 
        {"MTHS 10 TO 12", each List.Sum([Month10to12]), type number}, 
        {"MTHS 12+", each List.Sum([Month12Up]), type number}}),
    #"Sorted Rows1" = Table.Sort(#"Grouped Rows",{{"Line Num", Order.Ascending}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Sorted Rows1",{{"EFFDATE", type date}})
in
    #"Changed Type"