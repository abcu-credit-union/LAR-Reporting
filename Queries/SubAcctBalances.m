/********************************************************************************************************************************************************
4/26/2019 ZW: There are now two source columns in this query. SOURCE provided in the SQL (old method) and Source DB added through Table.AddColumn. Need
    to go through the remaining queries and update them to Source DB method so SQL can be merged into one statement.

********************************************************************************************************************************************************/


let
    StartDate = Text.From(ReportDate[Date]{0}),
    BCUSource = Table.AddColumn(Oracle.Database("BCUDatabase", [Query="
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
                WHERE
                    EFFDATE <= TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
                GROUP BY
                    ACCTNBR, 
                    SUBACCTNBR) MaxDateBal
            ON ACCTBALHIST.ACCTNBR = MaxDateBal.ACCTNBR
                AND ACCTBALHIST.SUBACCTNBR = MaxDateBal.SUBACCTNBR
                AND ACCTBALHIST.EFFDATE = MaxDateBal.MaxEffDate
            INNER JOIN ACCT
                ON ACCTBALHIST.ACCTNBR = ACCT.ACCTNBR
                AND ACCT.CURRACCTSTATCD NOT IN ('CO', 'CLS')
        WHERE ACCTBALHIST.BALAMT <> 0"]),
    "Source DB", each "Beaumont", type text),
    RCCUSource = Table.AddColumn(Oracle.Database("RCCUDatabase", [Query="
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
                WHERE
                    EFFDATE <= TO_DATE('"&StartDate&"', 'MM/DD/YYYY')
                GROUP BY
                    ACCTNBR,
                    SUBACCTNBR) MaxDateBal
            ON ACCTBALHIST.ACCTNBR = MaxDateBal.ACCTNBR
                AND ACCTBALHIST.SUBACCTNBR = MaxDateBal.SUBACCTNBR
                AND ACCTBALHIST.EFFDATE = MaxDateBal.MaxEffDate
            INNER JOIN ACCT
                ON ACCTBALHIST.ACCTNBR = ACCT.ACCTNBR
                AND ACCT.CURRACCTSTATCD NOT IN ('CO', 'CLS')
         WHERE ACCTBALHIST.BALAMT <> 0"]),
    "Source DB", each "City Centre", type text),
    ABCUSource = Table.Combine({BCUSource, RCCUSource})
in
    ABCUSource
