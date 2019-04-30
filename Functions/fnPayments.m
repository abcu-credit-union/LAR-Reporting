// fnPayments
/**********************************************************************************************************ABANDON ALL HOPE YE WHO ENTER HERE******************************************************************************************************************/
/*This function calculates princpal payments to be recieved and creates a record for each row.
*/

/*To Do:
    + Determine specific per product requirements
    + "Path" the function cleanly so a **** load of ifs don't need to be used
*/

/*************************************************************************************************************************************************************************************************************************************************************/

let
    fnPayments = (Line, BAL, ALPI, AMOR) =>
        let payments = if List.Contains({2822, 2825, 2828, 2832}, Line) and BAL <> 0 and ALPI <> 0 and AMOR <> 0 then
            let
                PmtAmt = BAL/AMOR,
                Mth1 = if AMOR >= 1 then
                    PmtAmt
                else
                    0,
                Mth2 = if AMOR >= 2 then
                    PmtAmt
                else
                    0,
                Mth3 = if AMOR >= 3 then
                    PmtAmt
                else
                    0,
                Mth4to6 = if (AMOR - 3) >= 0 and (AMOR - 3) <= 3 then
                    PmtAmt * (AMOR - 3)
                else if (AMOR -3) > 3 then
                    PmtAmt * 3
                else
                    0,
                Mth7to9 = if (AMOR - 6) >= 0 and (AMOR - 6) <= 3 then
                    PmtAmt * (AMOR - 6)
                else if (AMOR - 6) > 3 then
                    PmtAmt * 3
                else
                    0,
                Mth10to12 = if (AMOR - 9) >= 0 and (AMOR - 9) <= 3 then
                    PmtAmt * (AMOR - 9)
                else if (AMOR - 9) > 3 then
                    PmtAmt * 3
                else
                    0,
                Mth12Up = BAL - (Mth1 + Mth2 + Mth3 + Mth4to6 + Mth7to9 + Mth10to12),
                CnsDetRecord = [Month1 = Mth1, Month2 = Mth2, Month3 = Mth3, Month4to6 = Mth4to6, Month7to9 = Mth7to9, Month10to12 = Mth10to12, Month12Up = Mth12Up]
            in
                CnsDetRecord
        else if BAL <= ALPI then
            let
                FinalPmtRecord = [Month1 = BAL, Month2 = 0, Month3 = 0, Month4to6 = 0, Month7to9 = 0, Month10to12 = 0, Month12Up = 0]
            in
                FinalPmtRecord
        
        /*The following section is outflows for line 2841 on the F&S - these are in a declining balance basis*/
        else if Line = 2841 then
            let
                Mth1 = BAL * 0.03,
                Mth2 = (BAL - Mth1) * 0.01,
                Mth3 = (BAL - (Mth1 + Mth2)) * 0.01,
                Mth4 = (BAL - (Mth1 + Mth2 + Mth3)) * 0.01,
                Mth5 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4)) * 0.01,
                Mth6 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5)) * 0.01,
                Mth7 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6)) * 0.01,
                Mth8 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7)) * 0.01,
                Mth9 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8)) * 0.01,
                Mth10 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8 + Mth9)) * 0.01,
                Mth11 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8 + Mth9 + Mth10)) * 0.01,
                Mth12 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8 + Mth9 + Mth10 + Mth11)) * 0.01,
                Mth12Up = BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8 + Mth9 + Mth10 + Mth11 + Mth12),
                Record = [Month1 = Mth1, Month2 = Mth2, Month3 = Mth3, Month4to6 = (Mth4 + Mth5 + Mth6), Month7to9 = (Mth7 + Mth8 + Mth9), Month10to12 = (Mth10 + Mth11 + Mth12), Month12Up = Mth12Up]
            in
                Record

        /* Outflows for line 2842 on the F&S*/
        else if Line = 2842 then
            let
                Mth1 = BAL * 0.03,
                Mth2 = (BAL - Mth1) * 0.01,
                Mth3 = (BAL - (Mth1 + Mth2)) * 0.01,
                Mth4 = (BAL - (Mth1 + Mth2 + Mth3)) * 0.01,
                Mth5 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4)) * 0.01,
                Mth6 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5)) * 0.01,
                Mth7 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6)) * 0.01,
                Mth8 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7)) * 0.01,
                Mth9 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8)) * 0.01,
                Mth10 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8 + Mth9)) * 0.01,
                Mth11 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8 + Mth9 + Mth10)) * 0.01,
                Mth12 = (BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8 + Mth9 + Mth10 + Mth11)) * 0.01,
                Mth12Up = BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8 + Mth9 + Mth10 + Mth11 + Mth12),
                Record = [Month1 = Mth1, Month2 = Mth2, Month3 = Mth3, Month4to6 = (Mth4 + Mth5 + Mth6), Month7to9 = (Mth7 + Mth8 + Mth9), Month10to12 = (Mth10 + Mth11 + Mth12), Month12Up = Mth12Up]
            in
                Record

        /*Outflows for line 2843 on the F&S*/
        else if Line = 2843 then
            let
                Mth1 = if AMOR <= 1 then
                    BAL * 0.03
                else
                    0,
                Mth2 = if AMOR = 2 then
                    BAL * 0.01
                else 
                    0,
                Mth3 = if AMOR = 3 then
                    BAL * 0.01
                else 
                    0,
                Mth4 = if AMOR = 4 then
                    BAL * 0.01
                else 
                    0,
                Mth5 = if AMOR = 5 then
                    BAL * 0.01
                else 
                    0,
                Mth6 = if AMOR = 6 then
                    BAL * 0.01
                else 
                    0,
                Mth7 = if AMOR = 7 then
                    BAL * 0.01
                else 
                    0,
                Mth8 = if AMOR = 8 then
                    BAL * 0.01
                else 
                    0,
                Mth9 = if AMOR = 9 then
                    BAL * 0.01
                else 
                    0,
                Mth10 = if AMOR = 10 then
                    BAL * 0.01
                else 
                    0,
                Mth11 = if AMOR = 11 then
                    BAL * 0.01
                else 
                    0,
                Mth12 = if AMOR = 12 then
                    BAL * 0.01
                else 
                    0,
                Mth12Up = BAL - (Mth1 + Mth2 + Mth3 + Mth4 + Mth5 + Mth6 + Mth7 + Mth8 + Mth9 + Mth10 + Mth11 + Mth12),
                Record = [Month1 = Mth1, Month2 = Mth2, Month3 = Mth3, Month4to6 = (Mth4 + Mth5 + Mth6), Month7to9 = (Mth7 + Mth8 + Mth9), Month10to12 = (Mth10 + Mth11 + Mth12), Month12Up = Mth12Up]
            in
                Record  
        else
            [Month1 = 0, Month2 = 0, Month3 = 0, Month4to6 = 0, Month7to9 = 0, Month10to12 = 0, Month12Up = 0]
    in
        payments
in
    fnPayments
