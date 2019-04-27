let
    StartDate = Text.From(ReportDate[Date]{0}), 
    BCUSource = Oracle.Database("BCUDatabase", [Query=
        "SELECT
            'BCU' AS SOURCE, 
            WH_ACCTCOMMON.ACCTNBR,
            BalSubAcct.SUBACCTNBR, 
            WH_ACCTCOMMON.EFFDATE, 
            WH_ACCTCOMMON.MJACCTTYPCD, 
            WH_ACCTCOMMON.NOTEBAL, 
            WH_ACCTCOMMON.CURRACCTSTATCD, 
            WH_ACCTCOMMON.CURRMIACCTTYPCD,
            BalSubAcct.BALCATCD,
            BalSubAcct.BALTYPCD,
            COALESCE(CEIL(MONTHS_BETWEEN(ACCT.DATEMAT, TO_DATE('"&StartDate&"','MM/DD/YYYY'))), 0) AS RemainingAmortization,
            COALESCE(WH_ACCTLOAN.TOTALPI, 0) AS TOTALPI,
            WH_ACCTCOMMON.TAXRPTFORPERSNBR,
            WH_ACCTCOMMON.TAXRPTFORORGNBR
        FROM WH_ACCTCOMMON
            INNER JOIN 
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
            LEFT OUTER JOIN WH_ACCTLOAN
               ON WH_ACCTCOMMON.ACCTNBR = WH_ACCTLOAN.ACCTNBR AND
                    WH_ACCTCOMMON.EFFDATE = WH_ACCTLOAN.EFFDATE            
        WHERE WH_ACCTCOMMON.EFFDATE = TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
            AND WH_ACCTCOMMON.NOTEBAL <> 0
            AND ((WH_ACCTCOMMON.MJACCTTYPCD = 'CK' AND WH_ACCTCOMMON.NOTEBAL < 0)
                OR (WH_ACCTCOMMON.MJACCTTYPCD = 'SAV' AND WH_ACCTCOMMON.NOTEBAL < 0)
                OR WH_ACCTCOMMON.MJACCTTYPCD = 'CNS'
                OR WH_ACCTCOMMON.MJACCTTYPCD = 'CML'
                OR WH_ACCTCOMMON.MJACCTTYPCD = 'MTG')
    "]),
    RCCUSource = Oracle.Database("RCCUDatabase", [Query=
        "SELECT
            'RCCU' AS SOURCE, 
            WH_ACCTCOMMON.ACCTNBR,
            BalSubAcct.SUBACCTNBR, 
            WH_ACCTCOMMON.EFFDATE, 
            WH_ACCTCOMMON.MJACCTTYPCD, 
            WH_ACCTCOMMON.NOTEBAL, 
            WH_ACCTCOMMON.CURRACCTSTATCD, 
            WH_ACCTCOMMON.CURRMIACCTTYPCD,
            BalSubAcct.BALCATCD,
            BalSubAcct.BALTYPCD,
            COALESCE(CEIL(MONTHS_BETWEEN(ACCT.DATEMAT, TO_DATE('"&StartDate&"','MM/DD/YYYY'))), 0) AS RemainingAmortization,
            COALESCE(WH_ACCTLOAN.TOTALPI, 0) AS TOTALPI,
            WH_ACCTCOMMON.TAXRPTFORPERSNBR,
            WH_ACCTCOMMON.TAXRPTFORORGNBR
        FROM WH_ACCTCOMMON
            INNER JOIN 
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
            LEFT OUTER JOIN WH_ACCTLOAN
               ON WH_ACCTCOMMON.ACCTNBR = WH_ACCTLOAN.ACCTNBR AND
                    WH_ACCTCOMMON.EFFDATE = WH_ACCTLOAN.EFFDATE            
        WHERE WH_ACCTCOMMON.EFFDATE = TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
            AND WH_ACCTCOMMON.NOTEBAL <> 0
            AND ((WH_ACCTCOMMON.MJACCTTYPCD = 'CK' AND WH_ACCTCOMMON.NOTEBAL < 0)
                OR (WH_ACCTCOMMON.MJACCTTYPCD = 'SAV' AND WH_ACCTCOMMON.NOTEBAL < 0)
                OR WH_ACCTCOMMON.MJACCTTYPCD = 'CNS'
                OR WH_ACCTCOMMON.MJACCTTYPCD = 'CML'
                OR WH_ACCTCOMMON.MJACCTTYPCD = 'MTG')
    "]),
    ABCUSource = Table.Combine({BCUSource, RCCUSource}),


//Account balances are added from the SubAcctBalances query.  These balances are what DNA considers principal only balances
    #"Added Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(ABCUSource, {"SOURCE", "ACCTNBR", "SUBACCTNBR"}, SubAcctBalances, {"SOURCE", "ACCTNBR", "SUBACCTNBR"}, "Balances", JoinKind.LeftOuter),
    "Balances", {"BALAMT"}),

//IFRS 9 reporting must be completed prior to starting NCCF and NSFR.  During IFRS 9 reporting a report is generated that provides loan stages, ECL amounts (on an account level)
//That information is imported into this workbook and used new row is created with the loan stage.
    #"Added loan stages" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added Balances", {"SOURCE", "ACCTNBR"}, IFRS9LoanStages, {"Source", "Account Number"}, "Stages", JoinKind.LeftOuter),
    "Stages", {"Stage", "Final Loan ECL"}, {"IFRS9 Stage", "ECL"}),

//ADO's report as a negative value, an absolute function is used to change all values to positive
    #"Adjusted Balances" = Table.FromRecords(
        Table.TransformRows(#"Added loan stages", (r) => Record.TransformFields(r,
        {{"BALAMT", each Number.Abs( _) - r[ECL]}}))),

//The following is a basic IF statement that looks at loan stages, product type and remaining amortization to determine the correct line for reporting.  If none of the statements
//are met an error code of 9999 is returned
    #"Added line number" = Table.AddColumn(#"Adjusted Balances", "Line Number", each if [IFRS9 Stage] = 1 and [REMAININGAMORTIZATION] < 12 then
        2738 
    else if [IFRS9 Stage] = 1 and [MJACCTTYPCD] = "MTG" and [REMAININGAMORTIZATION] >= 12 then
        2741
    else if [IFRS9 Stage] = 1 and [REMAININGAMORTIZATION] >= 12 then
        2742
    else if [IFRS9 Stage] <> 1 then
        2743
    else
        9999),
    //Results are aggregated for reporting
    #"Grouped Rows" = Table.Group(#"Added line number", {"EFFDATE", "Line Number"}, {{"FP BALANCE", each List.Sum([BALAMT]), type number}})
in
    #"Grouped Rows"