/*****************************************************************************************************************************************************
4/26/2019 - Zac White: Feedback from Robin has identified that deposits are not being classified correctly.



******************************************************************************************************************************************************/
let
    StartDate = Text.From(ReportDate[Date]{0}),

    SQL =
"SELECT
	WH_ACCTCOMMON.ACCTNBR,
        WH_ACCTCOMMON.OWNERNAME,
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
	(CASE WHEN WH_ACCTCOMMON.TAXRPTFORPERSNBR IS NOT NULL THEN 'P' || WH_ACCTCOMMON.TAXRPTFORPERSNBR
            ELSE 'O' || WH_ACCTCOMMON.TAXRPTFORORGNBR END) ""Entity""
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
	AND WH_ACCTCOMMON.CURRMIACCTTYPCD NOT IN ('ECSC', 'ECSM', 'FCSC', 'FCSM')",

/*
4/26/2019 ZW: Changed source to be a column add instead of handling if the SQL. This will break the source joins to other queries since they are using
old structure of BCU and RCCU instead of Beaumont and City Centre.
*/

    BBSource = Table.AddColumn(
        Oracle.Database("BCUDatabase", [Query= ""&SQL&""]),
    "Source DB", each "Beaumont"),
    CCSource = Table.AddColumn(
        Oracle.Database("RCCUDatabase", [Query= ""&SQL&""]),
    "Source DB", each "City Centre"),
    ABCUSource = Table.Combine({BBSource, CCSource}),

/*    
Account balances are added from the SubAcctBalances query.  These balances are what DNA considers principal only balances
4/26/2019 ZW: Adjusted join to use "Source DB" column on both tables
*/

    #"Added Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(ABCUSource, {"Source DB", "ACCTNBR", "SUBACCTNBR"}, SubAcctBalances, {"Source DB", "ACCTNBR", "SUBACCTNBR"}, "Balances", JoinKind.LeftOuter),
    "Balances", {"BALAMT"}),

/*
Currency information is pulled on an account level.  
After USD and CAD balances have been identified this code translates USD to CAD using the month end FX rate
*/

   #"Converted USD to CAD" = Table.AddColumn(
        Table.ExpandTableColumn(
            Table.NestedJoin(#"Added Balances", {"EFFDATE"}, FXRates, {"Date"}, "FX Rates", JoinKind.LeftOuter),
        "FX Rates", {"Rate"}),
    "Adj BALAMT", each if [CURRENCYCD] = "USD" then
        [BALAMT] * [Rate]
    else
        [BALAMT]),
/*
This is a basic if statement that checks the remaining maturity on the deposit to determine what line number it should be reported on
4/26/2019 ZW: Entities need to be grouped to identify those that pass the $5M threshold as a business deposit. However this will result in
    maturity information. Grouping for total deposit amount will need to be an intermediate step which is joined to a primary step.
*/

/*
        The subsection below groups deposits on Source DB and Entity before assigning a deposit class. The deposit class is determined by
        fnDepositType()
*/

        #"Grouped Entities" = Table.Group(#"Converted USD to CAD", {"Entity", "OWNERNAME", "Source DB"},
            {{"Balance", each List.Sum([BALAMT]), type number},
            {"Accounts", each List.Distinct([CURRMIACCTTYPCD])}}),
        #"Added Deposit Class" = Table.AddColumn(#"Grouped Entities", "Deposit Type",
            each Record.Field(
                fnDepositType([Entity], [OWNERNAME], [Balance], [Accounts]),
            "Value")),

/*
Subquery is joined to the main table in the #"Joined Deposit Class" step
*/

    #"Joined Deposit Class" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Converted USD to CAD", {"Entity", "Source DB"}, #"Added Deposit Class", {"Entity", "Source DB"}, "Class", JoinKind.LeftOuter),
    "Class", {"Deposit Type"}),        

    #"Added Line Number" = Table.AddColumn(#"Joined Deposit Class", "Line Number", 
        each if [REMAININGAMORTIZATION] = null and [Deposit Type] <> "Business" then
            2701
        else if [REMAININGAMORTIZATION] < 12 and [Deposit Type] <> "Business" then
            2703
        else if [REMAININGAMORTIZATION] = null and [Deposit Type] = "Business" then
            2702
        else if [REMAININGAMORTIZATION] < 12 and [Deposit Type] = "Business" then
            2704
        else if [REMAININGAMORTIZATION] >= 12 then
            2705
        else
            9999),

/*
This aggregates the values for reporting purposes
*/

    #"Grouped Rows" = Table.Group(#"Added Line Number", {"EFFDATE", "Line Number"}, {{"FP BALANCE", each List.Sum([Adj BALAMT]), type number}})
in
    #"Grouped Rows"
