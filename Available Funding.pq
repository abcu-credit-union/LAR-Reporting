/*****************************************************************************************************************************************************
4/26/2019 - Zac White: Feedback from Robin has identified that deposits are not being classified correctly.



******************************************************************************************************************************************************/
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
            WH_ACCTCOMMON.PRODUCT,
            BalSubAcct.BALCATCD,
            BalSubAcct.BALTYPCD,
            MJMIACCTTYP.CURRENCYCD,
            CEIL(MONTHS_BETWEEN(ACCT.DATEMAT, TO_DATE('"&StartDate&"','MM/DD/YYYY'))) AS RemainingAmortization,
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
            WH_ACCTCOMMON.PRODUCT,
            BalSubAcct.BALCATCD,
            BalSubAcct.BALTYPCD,
            MJMIACCTTYP.CURRENCYCD,
            CEIL(MONTHS_BETWEEN(ACCT.DATEMAT, TO_DATE('"&StartDate&"','MM/DD/YYYY'))) AS RemainingAmortization,
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
    "]),
    ABCUSource = Table.Combine({BCUSource, RCCUSource}),
    
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