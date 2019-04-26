// fnOutflowLine
/*Notes:
    + F&S Completion guidelines for NCCF describes outflow treatment as being for liabilities. Share accounts would not be included as a result since they are an equity.
    + An assumption is being made that all redeemable TD products have Redeemable in the name.  If something is redeemable but does not include "Redeemable" in the name it will be mapped to "Non-redeemable Specific Maturity"
*/
/*************************************************************************************************************************************************************************************************************************************************************/

let
    fnOutflowLine = (MJACCTTYPCD, CURRMIACCTTYPCD, PRODUCT, PERSNBR, ORGNBR) =>
        let
           lineNum = if List.Contains({"CK", "SAV"}, MJACCTTYPCD) then
                2841
            else if Text.Contains(Text.Lower(PRODUCT), "non") = false and Text.Contains(Text.Lower(PRODUCT), "redeemable") then
                2842
            else
                2843
        in 
            lineNum
in
    fnOutflowLine