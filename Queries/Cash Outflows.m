/*************************************************************************************************************************************************************************************************************************************************************/

let
    StartDate = Text.From(ReportDate[Date]{0}),

    SQL =
"SELECT
    ACCT.BRANCHORGNBR,
    WH_ACCTCOMMON.ACCTNBR,
    ACCTSUBACCT.SUBACCTNBR,
    WH_ACCTCOMMON.EFFDATE,
    WH_ACCTCOMMON.PRODUCT,
    WH_ACCTCOMMON.MJACCTTYPCD,
    WH_ACCTCOMMON.CURRMIACCTTYPCD,
    WH_ACCTCOMMON.NOTEINTRATE,
    ACCTSUBACCT.BALCATCD,
    SUBSTR(GLACCT.XREFGLACCTNBR, 0, 8) ""GL Number"",
    SUBSTR(GLACCT.XREFGLACCTNBR, -3) ""Cost Center"",
    COALESCE(CEIL(MONTHS_BETWEEN(ACCT.DATEMAT, TO_DATE('"&StartDate&"','MM/DD/YYYY'))), 0) AS RemainingAmortization,
    COALESCE(WH_ACCTLOAN.TOTALPI, 0) AS TOTALPI,
    (CASE WHEN WH_ACCTCOMMON.TAXRPTFORPERSNBR IS NOT NULL THEN 'P' || WH_ACCTCOMMON.TAXRPTFORPERSNBR
        ELSE 'O' || WH_ACCTCOMMON.TAXRPTFORORGNBR END) ""Entity""
FROM WH_ACCTCOMMON
INNER JOIN ACCT
    ON WH_ACCTCOMMON.ACCTNBR = ACCT.ACCTNBR
LEFT OUTER JOIN WH_ACCTLOAN
    ON WH_ACCTCOMMON.ACCTNBR = WH_ACCTLOAN.ACCTNBR
    AND WH_ACCTCOMMON.EFFDATE = WH_ACCTLOAN.EFFDATE
INNER JOIN ACCTSUBACCT
    ON WH_ACCTCOMMON.ACCTNBR = ACCTSUBACCT.ACCTNBR
    AND ACCTSUBACCT.BALTYPCD = 'BAL'
INNER JOIN MJMIACCTGL
    ON WH_ACCTCOMMON.MJACCTTYPCD = MJMIACCTGL.MJACCTTYPCD
    AND WH_ACCTCOMMON.CURRMIACCTTYPCD = MJMIACCTGL.MIACCTTYPCD
    AND ACCTSUBACCT.BALCATCD = MJMIACCTGL.BALCATCD
    AND ACCTSUBACCT.BALTYPCD = MJMIACCTGL.BALTYPCD
    AND MJMIACCTGL.INACTIVEDATE IS NULL
INNER JOIN GLACCT
    ON MJMIACCTGL.GLACCTTITLENBR = GLACCT.GLACCTTITLENBR
    AND SUBSTR(GLACCT.XREFGLACCTNBR, -3) = ACCT.BRANCHORGNBR
WHERE
    WH_ACCTCOMMON.EFFDATE = TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
    AND WH_ACCTCOMMON.NOTEBAL > 0
    AND WH_ACCTCOMMON.MJACCTTYPCD IN ('CK', 'SAV', 'TD')
    AND WH_ACCTCOMMON.CURRMIACCTTYPCD NOT IN ('ECSC', 'ECSM', 'FCSC', 'FCSM')
    AND (WH_ACCTCOMMON.TAXRPTFORORGNBR NOT IN (1402, 786)
        OR WH_ACCTCOMMON.TAXRPTFORORGNBR IS NULL)
    AND LOWER(WH_ACCTCOMMON.PRODUCT) NOT LIKE '%internal%'",

    BBSource = Table.AddColumn(
        Oracle.Database("BCUDatabase", [Query = ""&SQL&""]),
    "Source DB", each "Beaumont", type text),
    CCSource = Table.AddColumn(
        Oracle.Database("RCCUDatabase", [Query = ""&SQL&""]),
    "Source DB", each "City Centre", type text),
    ABCUSource = Table.Combine({BBSource, CCSource}),

/*
This section adds account balances from the SubAcctBalances table.
*/
    #"Added Account Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(ABCUSource, {"ACCTNBR", "SUBACCTNBR"}, SubAcctBalances, {"ACCTNBR", "SUBACCTNBR"}, "BAL", JoinKind.Inner),
    "BAL", {"BALAMT"}, {"Account Balance"}),

    #"Changed Type" = Table.TransformColumnTypes(#"Added Account Balances",
        {{"GL Number", type number},
        {"Cost Center", type number}}),

/*
As a result of the GL conversion, some GL's in January are returning a null value. The two steps below convert back to the
old GLs if the report date is 1/31/2019
*/
    #"Added Old Gls" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Changed Type", {"Source DB", "GL Number"},
            #"GL Conversion Table", {"Source DB", "New GL"}, "GLs", JoinKind.LeftOuter),
        "GLs", {"Old GL"}),

    #"Transformed GLs" = Table.FromRecords(
        Table.TransformRows(#"Added Old Gls", (r) => Record.TransformFields(r,
            {{"GL Number", each if StartDate = "1/31/2019" and r[Old GL] <> null then
                r[Old GL]
            else _}}))),


/*
FR2900 codes and FSMS line are added from the FAS query. This join is occuring on the GL number and cost center
*/
    #"Added GL Codes" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Transformed GLs", {"GL Number", "Cost Center"},
            FASQuery, {"UserAcctNum", "OrgShortName"},
        "GL", JoinKind.LeftOuter),
    "GL", {"FR2900Code", "FSMS Line"}),
/*
An ABS function is used to convert all values to a positive so that a weighted average can be used to convert DNA balances
to FAS balances
*/
    #"Adjusted Account Balances" = Table.TransformColumns(#"Added GL Codes",
        {{"Account Balance", each Number.Abs(_), type number}}),

        /*
        This is a substep that is totaling DNA balances based on the associated FR code and cost center
        */

        #"Grouped Rows" = Table.Group(#"Adjusted Account Balances", {"FR2900Code", "Cost Center"},
            {{"Sum", each List.Sum([Account Balance]), type number}}),
/*
The totals are added into the main query during this step.
*/
    #"Added DNA GL Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Adjusted Account Balances", {"FR2900Code", "Cost Center"},
            #"Grouped Rows", {"FR2900Code", "Cost Center"},
        "Prod Bal", JoinKind.LeftOuter),
    "Prod Bal", {"Sum"}, {"DNA Balance"}),

        /*
        Another substep here. This is totaling the FAS balances based on the FR2900 codes
        */
        #"Grouped FR2900 Codes" = Table.Group(FASQuery, {"FR2900Code", "OrgShortName"},
            {"Balance", each List.Sum([YTDBal]), type number}),
/*
Adding FAS balances back to the main query
*/
    #"Added FR Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added DNA GL Balances", {"FR2900Code", "Cost Center"},
            #"Grouped FR2900 Codes", {"FR2900Code", "OrgShortName"},
        "FRBal", JoinKind.LeftOuter),
    "FRBal", {"Balance"}, {"FR Balance"}),
/*
NCCF should only reflect principle balances of loan and lease recievables. This coresponds with line 141 on the F&S.
The below step filters based on this
*/
    #"Filtered Rows" = Table.SelectRows(#"Added FR Balances",
        each ([FSMS Line] = "FP301")),
/*
Weighted average is used to convert DNA balances to principle only FAS balances
*/
    #"Added FP Balances" = Table.AddColumn(#"Filtered Rows", "FP Balance",
        each ([Account Balance] / [DNA Balance]) * [FR Balance], type number),


        #"Grouped Entities" = Table.Group(#"Added FP Balances", {"Entity", "Source DB"},
            {{"Balance", each List.Sum([FP Balance]), type number},
            {"Accounts", each List.Distinct([CURRMIACCTTYPCD])}}),
        #"Added Deposit Class" = Table.AddColumn(#"Grouped Entities", "Deposit Type",
            each Record.Field(
                fnDepositType([Entity], [Balance], [Accounts]),
            "Value")),

    #"Joined Deposit Class" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added FP Balances", {"Entity", "Source DB"},
            #"Added Deposit Class", {"Entity", "Source DB"},
        "Class", JoinKind.LeftOuter),
    "Class", {"Deposit Type"}),

    #"Checked for Wholesale Deposits" = Table.FromRecords(
        Table.TransformRows(#"Joined Deposit Class", (r) => Record.TransformFields(r,
            {{"Deposit Type", each if _ = "Business"
                and (r[FP Balance] >= 1000000
                    and r[NOTEINTRATE] >= 0.0395
                    and List.Contains({"CK", "SAV"}, r[MJACCTTYPCD]))
                or (r[FP Balance] >= 1000000
                    and r[MJACCTTYPCD] = "TD"
                    and r[REMAININGAMORTIZATION] <= 12) then
                "Wholesale" else _}}))),

    #"Added Line Numbers" = Table.AddColumn(#"Checked for Wholesale Deposits", "Line Num",
        each fnOutflowLine([MJACCTTYPCD], [CURRMIACCTTYPCD], [PRODUCT], [Entity], [Deposit Type]), type number),


    #"Added Liquidity Balance" = Table.AddColumn(#"Added Line Numbers", "Liquidity Balance",
        each [FP Balance], type number),

    #"Added Outflows" = Table.ExpandRecordColumn(
        Table.AddColumn(#"Added Liquidity Balance", "Outflows",
            each fnPayments([Line Num], [Liquidity Balance], [TOTALPI], [REMAININGAMORTIZATION])),
    "Outflows", {"Month1", "Month2", "Month3", "Month4to6", "Month7to9", "Month10to12", "Month12Up"}),

    #"Grouped Results" = Table.Group(#"Added Outflows", {"EFFDATE", "Line Num"},
           {{"FP BAL", each List.Sum([FP Balance]), type number},
           {"LIQUIDITY BAL", each List.Sum([Liquidity Balance]), type number},
           {"MTH 1", each List.Sum([Month1]), type number},
           {"MTH 2", each List.Sum([Month2]), type number},
           {"MTH 3", each List.Sum([Month3]), type number},
           {"MTHS 4 TO 6", each List.Sum([Month4to6]), type number},
           {"MTHS 7 TO 9", each List.Sum([Month7to9]), type number},
           {"MTHS 10 TO 12", each List.Sum([Month10to12]), type number},
           {"MTHS 12+", each List.Sum([Month12Up]), type number}})

in
    #"Grouped Results"
