/*************************************************************************************************************************************************************************************************************************************************************/
/*
Both BCUSource and RCCUSource are passing identical SQL statements to their respective DNA systems,
the results are then merged to create ABCUSource
*/
let
    StartDate = Text.From(ReportDate[Date]{0}),
    LIPBalance = Number.From(
        Table.SelectRows(FASQuery,
            each [UserAcctNum] = 11507128)[YTDBal]
    {0}),

	SQL =
"SELECT
    ACCT.BRANCHORGNBR,
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
        ACCTSUBACCT.ACCTNBR,
        ACCTSUBACCT.SUBACCTNBR,
        ACCT.MJACCTTYPCD,
        ACCTSUBACCT.BALCATCD,
        ACCTSUBACCT.BALTYPCD
    FROM ACCTSUBACCT
    INNER JOIN ACCT
        ON ACCTSUBACCT.ACCTNBR = ACCT.ACCTNBR
    WHERE (ACCT.MJACCTTYPCD NOT IN ('CK', 'SAV')
            AND ACCTSUBACCT.BALTYPCD = 'BAL'
            AND ACCTSUBACCT.BALCATCD = 'NOTE')
        OR (ACCT.MJACCTTYPCD IN ('CK', 'SAV')
            AND ACCTSUBACCT.BALTYPCD = 'BAL'
            AND ACCTSUBACCT.BALCATCD IN ('LMOD', 'ODEX'))) BalSubAcct
	ON WH_ACCTCOMMON.ACCTNBR = BalSubAcct.ACCTNBR
INNER JOIN ACCT
    ON WH_ACCTCOMMON.ACCTNBR = ACCT.ACCTNBR
LEFT OUTER JOIN WH_ACCTLOAN
    ON WH_ACCTCOMMON.ACCTNBR = WH_ACCTLOAN.ACCTNBR
    AND WH_ACCTCOMMON.EFFDATE = WH_ACCTLOAN.EFFDATE
WHERE WH_ACCTCOMMON.EFFDATE = TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
	AND WH_ACCTCOMMON.CURRACCTSTATCD NOT IN  ('CLS', 'CO')
	AND WH_ACCTCOMMON.NOTEBAL <> 0
	AND ((WH_ACCTCOMMON.MJACCTTYPCD = 'CK' AND WH_ACCTCOMMON.NOTEBAL < 0)
		OR (WH_ACCTCOMMON.MJACCTTYPCD = 'SAV' AND WH_ACCTCOMMON.NOTEBAL < 0)
		OR WH_ACCTCOMMON.MJACCTTYPCD = 'CNS'
		OR WH_ACCTCOMMON.MJACCTTYPCD = 'CML'
		OR WH_ACCTCOMMON.MJACCTTYPCD = 'MTG')",

    BBSource = Table.AddColumn(
        Oracle.Database("BCUDatabase", [Query = ""&SQL&""]),
    "Source DB", each "Beaumont", type text),
    CCSource = Table.AddColumn(
        Oracle.Database("RCCUDatabase", [Query= ""&SQL&""]),
    "Source DB", each "City Centre", type text),


    ABCUSource = Table.Combine({BBSource, CCSource}),

    #"Added GL Numbers" = Table.ExpandTableColumn(
        Table.NestedJoin(ABCUSource, {"BRANCHORGNBR", "MJACCTTYPCD", "CURRMIACCTTYPCD", "BALCATCD", "BALTYPCD"},
        DNAGLMapping, {"COSTCENTER", "MJACCTTYPCD", "MIACCTTYPCD", "BALCATCD", "BALTYPCD"}, "GL", JoinKind.LeftOuter),
    "GL", {"GLNUM", "GLACCTTITLENAME"}),
    #"Added GL Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added GL Numbers", {"BRANCHORGNBR", "GLNUM"},
        FASQuery, {"OrgShortName", "UserAcctNum"}, "GL Balance", JoinKind.LeftOuter),
    "GL Balance", {"YTDBal", "FR2900Code"}),
/*
LIP GLs are not joined. The #"Adjusted for LIP" step modifies the YTDBal to accurately reflect what is reported on the
F&S
*/
    #"Adjusted for LIP" = Table.FromRecords(
        Table.TransformRows(#"Added GL Balances", (r) => Record.TransformFields(r,
            {{"YTDBal", each if r[GLNUM] = 11501120 and r[BRANCHORGNBR] = 332 then
                _ + LIPBalance
            else _}}))
    ),

/*
ACCTSUBACCTBAL is used to provide balances.  This table seperates balances into principal, accrued interest, etc.
This is most reflective of the the "principal only balances" set out in NCCF
*/

    #"Added Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Adjusted for LIP", {"Source DB", "ACCTNBR", "SUBACCTNBR"},
        SubAcctBalances, {"Source DB", "ACCTNBR", "SUBACCTNBR"}, "Balances", JoinKind.Inner),
    "Balances", {"BALAMT"}),
    #"Added Product Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added Balances", {"BRANCHORGNBR", "GLNUM"},
        InflowsDNAProductBal, {"BRANCHORGNBR", "GLNUM"}, "ProductBal", JoinKind.LeftOuter),
    "ProductBal", {"Product Balance"}),
/*
After IFRS9 data is uploaded a report is run that spits out loan stages and account numbers.
The following code matches accounts to their IFRS 9 loan stage
*/
    #"Added loan stages" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added Product Balances", {"Source DB", "ACCTNBR"},
        IFRS9LoanStages, {"Source DB", "Account Number"}, "Stages", JoinKind.LeftOuter),
    "Stages", {"Stage"}, {"IFRS9 Stage"}),
/*
An absolute function is used to translate negative balances (AOD's) to positive
*/
    #"Added FP Balance" = Table.AddColumn(#"Added loan stages", "FP Balance",
        each (Number.Abs([BALAMT])/[Product Balance]) * [YTDBal]),
/*
Calls a function that applies the correct F&S line number to the different cash inflows
*/
    #"Added Line Num" = Table.AddColumn(#"Added FP Balance", "Line Num",
        each fnInflowLine([MJACCTTYPCD], [CURRMIACCTTYPCD], [TAXRPTFORPERSNBR], [TAXRPTFORORGNBR])),
/*
A second function is used here to provide liquidity balances.  A function is used for these that assess each accounts information and
determines what cash inflows to account for
5/1/2019 ZW: Should be using FP Balance for the fnLiquidtyBalance function
*/
    #"Added Liquidity Balance" = Table.AddColumn(#"Added Line Num", "Liquidity Balance",
        each fnLiquidityBalance([FP Balance], [Line Num], [IFRS9 Stage], [TOTALPI])),
    #"Changed Type" = Table.TransformColumnTypes(#"Added Liquidity Balance",{{"Liquidity Balance", type number}}),
/*
This function creates the cash inflows, and outflows based on the criteria set out in the F&S completition guidelines.
A record is produced with each outflow grouped into its respective bucket, the next line of code expands those records.
*/
    #"Added Inflows" = Table.ExpandRecordColumn(
        Table.AddColumn(#"Changed Type", "Records", each fnPayments([Line Num], [Liquidity Balance], [TOTALPI], [REMAININGAMORTIZATION])),
    "Records", {"Month1", "Month2", "Month3", "Month4to6", "Month7to9", "Month10to12", "Month12Up"}),
    #"Sorted Rows" = Table.Sort(#"Added Inflows",{{"ACCTNBR", Order.Descending}, {"BALCATCD", Order.Descending}}),
/*
This aggregates the information for reporting purposes.
*/
    #"Grouped Rows" = Table.Group(#"Sorted Rows", {"EFFDATE", "Line Num"},
        {{"FP BAL", each List.Sum([FP Balance]), type number},
        {"LIQUIDITY BAL", each List.Sum([Liquidity Balance]), type number},
        {"MTH 1", each List.Sum([Month1]), type number},
        {"MTH 2", each List.Sum([Month2]), type number},
        {"MTH 3", each List.Sum([Month3]), type number},
        {"MTHS 4 TO 6", each List.Sum([Month4to6]), type number},
        {"MTHS 7 TO 9", each List.Sum([Month7to9]), type number},
        {"MTHS 10 TO 12", each List.Sum([Month10to12]), type number},
        {"MTHS 12+", each List.Sum([Month12Up]), type number}}),
    #"Sorted Rows1" = Table.Sort(#"Grouped Rows",{{"Line Num", Order.Ascending}}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Sorted Rows1",{{"EFFDATE", type date}})
in
    #"Changed Type1"
