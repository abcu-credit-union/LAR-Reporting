// fnOutflowLine
/*Notes:
    + F&S Completion guidelines for NCCF describes outflow treatment as being for liabilities. Share accounts would not be included as a result since they are an equity.
    + An assumption is being made that all redeemable TD products have Redeemable in the name.  If something is redeemable but does not include "Redeemable" in the name it will be mapped to "Non-redeemable Specific Maturity"
*/
/*************************************************************************************************************************************************************************************************************************************************************/

(major, minor, product, entity, depType) =>
    let
        outflowLine =
            {
                {List.Contains({"Retail", "Small Business"}, depType)
                    and List.Contains({"CK", "SAV"}, major),
                2841},
                {List.Contains({"Retail", "Small Business"}, depType)
                    and Text.Contains(Text.Lower(product), "non") = false,
                2842},
                {List.Contains({"Retail", "Small Business"}, depType)
                    and Text.Contains(Text.Lower(product), "non")
                    and (Text.Contains(Text.Lower(product), "redeem")
                        or Text.Contains(Text.Lower(product), "reddem")),
                2843},
                {depType = "Business"
                    and List.Contains({"CK", "SAV"}, major),
                2844},
                {depType = "Business"
                    and Text.Contains(Text.Lower(product), "non") = false,
                2845},
                {depType = "Business"
                    and Text.Contains(Text.Lower(product), "non")
                    and (Text.Contains(Text.Lower(product), "redeem")
                        or Text.Contains(Text.Lower(product), "reddem")),
                2846},
                {depType = "Wholesale"
                    and List.Contains({"CK", "SAV"}, major),
                2847},
                {depType = "Wholesale"
                    and Text.Contains(Text.Lower(product), "non") = false,
                2848},
                {depType = "Wholesale"
                    and Text.Contains(Text.Lower(product), "non")
                    and (Text.Contains(Text.Lower(product), "redeem")
                        or Text.Contains(Text.Lower(product), "reddem")),
                2851},
                {true, 9999}
            },

        Result = List.First(List.Select(outflowLine, each _{0} = true)){1}
    in
        Result
