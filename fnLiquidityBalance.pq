// fnLiquidityBalance
/*Because each line has different Liquidity Balance requirements, this function will be used to calculate liquidity balance.
*/

/*To Do:
    + Add notes explaining which line each if statement is for
    + This might not need a function.  Should this be integrated into the query?
*/

/*************************************************************************************************************************************************************************************************************************************************************/

let
    fnLiquidityBalance = (Balance, Line, Stage, ALPI) =>
        let
            LiquidityBal = if List.Contains({2822, 2825, 2828, 2832}, Line) and Stage = 1 and ALPI <> 0 then
                Balance
            else if List.Contains({2823, 2824, 2831}, Line) then
                0
            else if ALPI = 0 or Stage <> 1 then
                0
            else
                9999 
        in
            LiquidityBal
    in
        fnLiquidityBalance