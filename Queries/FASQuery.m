let
    StartDate = Date.ToText(ReportDate[Date]{0}, "yyyyMM"),
    BCUSource = Sql.Database("10.207.18.10", "AB332PFTI", [Query=
        "SELECT
            'BCU' AS SOURCE,
            GL_AcctBalHist.MonthYYYYMM,
            GL_Acct.InstNum,
            GL_Acct.GLAcctNum,
            GL_Acct.OrgNum,
            FTI_AcctTitle.UserAcctNum,
            FTI_Org.OrgShortName,
            GL_Acct.GLAcctTitleNum,
            GL_Acct.Description,
            GL_Acct.FR2900Code,
            GL_AcctBalHist.YTDBal ""YTDBal""
         FROM GL_ACCT
            LEFT OUTER JOIN FTI_AcctTitle
                ON GL_Acct.InstNum = FTI_AcctTitle.InstNum
                    AND GL_Acct.GLAcctTitleNum = FTI_AcctTitle.GLAcctTitleNum
            LEFT OUTER JOIN FTI_Org
                ON GL_Acct.InstNum = FTI_Org.InstNum
                    AND GL_Acct.OrgNum = FTI_Org.OrgNum
            LEFT OUTER JOIN GL_AcctBalHist
                ON GL_Acct.InstNum = GL_AcctBalHist.InstNum
                    AND GL_Acct.GLAcctNum = GL_AcctBalHist.GLAcctNum
        WHERE GL_AcctBalHist.MonthYYYYMM = '"&StartDate&"'
            AND FTI_Org.OrgShortName <> 0
            AND GL_AcctBalHist.YTDBal <> 0"]),
    RCCUSource = Sql.Database("10.207.18.10", "AB242PFTI", [Query=
        "SELECT
            'RCCU' AS SOURCE,
            GL_AcctBalHist.MonthYYYYMM,
            GL_Acct.InstNum,
            GL_Acct.GLAcctNum,
            GL_Acct.OrgNum,
            FTI_AcctTitle.UserAcctNum,
            FTI_Org.OrgShortName,
            GL_Acct.GLAcctTitleNum,
            GL_Acct.Description,
            GL_Acct.FR2900Code,
            GL_AcctBalHist.YTDBal ""YTDBal""
         FROM GL_ACCT
            LEFT OUTER JOIN FTI_AcctTitle
                ON GL_Acct.InstNum = FTI_AcctTitle.InstNum
                    AND GL_Acct.GLAcctTitleNum = FTI_AcctTitle.GLAcctTitleNum
            LEFT OUTER JOIN FTI_Org
                ON GL_Acct.InstNum = FTI_Org.InstNum
                    AND GL_Acct.OrgNum = FTI_Org.OrgNum
            LEFT OUTER JOIN GL_AcctBalHist
                ON GL_Acct.InstNum = GL_AcctBalHist.InstNum
                    AND GL_Acct.GLAcctNum = GL_AcctBalHist.GLAcctNum
        WHERE GL_AcctBalHist.MonthYYYYMM = '"&StartDate&"'
            AND FTI_Org.OrgShortName <> 0
            AND GL_AcctBalHist.YTDBal <> 0"]),

    ABCUSource = Table.Combine({BCUSource, RCCUSource}),
    #"Removed Columns" = Table.RemoveColumns(ABCUSource,{"InstNum", "GLAcctNum", "OrgNum", "GLAcctTitleNum"}),
    #"Added Mappings" = Table.ExpandTableColumn(
        Table.NestedJoin(#"Removed Columns", {"FR2900Code"}, GLMappings, {"FR2900 Code"}, "F&S Line", JoinKind.LeftOuter),
    "F&S Line", {"FSMS Line"})
in
    #"Added Mappings"
