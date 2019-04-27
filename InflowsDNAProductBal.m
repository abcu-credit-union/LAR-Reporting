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
	            AND ACCTSUBACCT.BALCATCD = 'LMOD')
                OR (ACCT.MJACCTTYPCD IN ('CK', 'SAV')
	            AND ACCTSUBACCT.BALTYPCD = 'BAL'
	            AND ACCTSUBACCT.BALCATCD = 'ODEX')) BalSubAcct
                ON WH_ACCTCOMMON.ACCTNBR = BalSubAcct.ACCTNBR
            INNER JOIN ACCT
                ON WH_ACCTCOMMON.ACCTNBR = ACCT.ACCTNBR
            LEFT OUTER JOIN WH_ACCTLOAN
               ON WH_ACCTCOMMON.ACCTNBR = WH_ACCTLOAN.ACCTNBR AND
                    WH_ACCTCOMMON.EFFDATE = WH_ACCTLOAN.EFFDATE            
        WHERE WH_ACCTCOMMON.EFFDATE = TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
            AND WH_ACCTCOMMON.CURRACCTSTATCD <> 'CLS'
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
	            AND ACCTSUBACCT.BALCATCD = 'LMOD')
                OR (ACCT.MJACCTTYPCD IN ('CK', 'SAV')
	            AND ACCTSUBACCT.BALTYPCD = 'BAL'
	            AND ACCTSUBACCT.BALCATCD = 'ODEX')) BalSubAcct
            ON WH_ACCTCOMMON.ACCTNBR = BalSubAcct.ACCTNBR
            INNER JOIN ACCT
                ON WH_ACCTCOMMON.ACCTNBR = ACCT.ACCTNBR
            LEFT OUTER JOIN WH_ACCTLOAN
               ON WH_ACCTCOMMON.ACCTNBR = WH_ACCTLOAN.ACCTNBR AND
                    WH_ACCTCOMMON.EFFDATE = WH_ACCTLOAN.EFFDATE            
        WHERE WH_ACCTCOMMON.EFFDATE = TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
            AND WH_ACCTCOMMON.CURRACCTSTATCD <> 'CLS'
            AND WH_ACCTCOMMON.NOTEBAL <> 0
            AND ((WH_ACCTCOMMON.MJACCTTYPCD = 'CK' AND WH_ACCTCOMMON.NOTEBAL < 0)
                OR (WH_ACCTCOMMON.MJACCTTYPCD = 'SAV' AND WH_ACCTCOMMON.NOTEBAL < 0)
                OR WH_ACCTCOMMON.MJACCTTYPCD = 'CNS'
                OR WH_ACCTCOMMON.MJACCTTYPCD = 'CML'
                OR WH_ACCTCOMMON.MJACCTTYPCD = 'MTG')
    "]),


    ABCUSource = Table.Combine({BCUSource, RCCUSource}),

//ACCTSUBACCTBAL is used to provide balances.  This table seperates balances into principal, accrued interest, etc.  This is most reflective of the the "principal only balances" set out in NCCF
    
    #"Added Balances" = Table.ExpandTableColumn(
        Table.NestedJoin(ABCUSource, {"SOURCE", "ACCTNBR", "SUBACCTNBR"}, SubAcctBalances, {"SOURCE", "ACCTNBR", "SUBACCTNBR"}, "Balances", JoinKind.LeftOuter),
    "Balances", {"BALAMT"}),
     #"Added GL Numbers" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Added Balances", {"BRANCHORGNBR", "MJACCTTYPCD", "CURRMIACCTTYPCD", "BALCATCD", "BALTYPCD"}, DNAGLMapping, {"COSTCENTER", "MJACCTTYPCD", "MIACCTTYPCD", "BALCATCD", "BALTYPCD"}, "GL", JoinKind.LeftOuter),
    "GL", {"GLNUM", "GLACCTTITLENAME"}),
    #"Filtered Rows" = Table.SelectRows(#"Added GL Numbers", each ([CURRACCTSTATCD] <> "CO" and [CURRACCTSTATCD] <> "NPFM")),
    #"Grouped Rows" = Table.Group(#"Filtered Rows", {"GLNUM", "BRANCHORGNBR"}, {{"Product Balance", each Number.Abs(List.Sum([BALAMT])), type number}})

in
    #"Grouped Rows"