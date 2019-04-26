// ReportDate
let
    Source = Excel.CurrentWorkbook(){[Name="Table8"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Date", type date}})
in
    #"Changed Type"

// SubAcctBalances
let
    StartDate = Text.From(ReportDate[Date]{0}),
    BCUSource = Oracle.Database("BCUDatabase", [Query="
        SELECT
            'BCU' AS SOURCE,
            ACCTBALHIST.ACCTNBR,
            ACCTBALHIST.SUBACCTNBR,
            ACCTBALHIST.EFFDATE,
            ACCTBALHIST.BALAMT
        FROM ACCTBALHIST
            INNER JOIN
                (SELECT
                    ACCTNBR,
                    SUBACCTNBR,
                    MAX(EFFDATE) AS MaxEffDate
                FROM ACCTBALHIST
                WHERE EFFDATE <= TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
                GROUP BY ACCTNBR, SUBACCTNBR) MaxDateBal
            ON ACCTBALHIST.ACCTNBR = MaxDateBal.ACCTNBR AND
                ACCTBALHIST.SUBACCTNBR = MaxDateBal.SUBACCTNBR AND
                ACCTBALHIST.EFFDATE = MaxDateBal.MaxEffDate
        WHERE ACCTBALHIST.BALAMT <> 0"]),
    RCCUSource = Oracle.Database("RCCUDatabase", [Query="
        SELECT
            'RCCU' AS SOURCE,
            ACCTBALHIST.ACCTNBR,
            ACCTBALHIST.SUBACCTNBR,
            ACCTBALHIST.EFFDATE,
            ACCTBALHIST.BALAMT
        FROM ACCTBALHIST
            INNER JOIN
                (SELECT
                    ACCTNBR,
                    SUBACCTNBR,
                    MAX(EFFDATE) AS MaxEffDate
                FROM ACCTBALHIST
                WHERE EFFDATE <= TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
                GROUP BY ACCTNBR, SUBACCTNBR) MaxDateBal
            ON ACCTBALHIST.ACCTNBR = MaxDateBal.ACCTNBR AND
                ACCTBALHIST.SUBACCTNBR = MaxDateBal.SUBACCTNBR AND
                ACCTBALHIST.EFFDATE = MaxDateBal.MaxEffDate
         WHERE ACCTBALHIST.BALAMT <> 0"]),
    ABCUSource = Table.Combine({BCUSource, RCCUSource})
in
    ABCUSource