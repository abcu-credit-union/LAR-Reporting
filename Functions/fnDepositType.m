(entity, balance, accounts) =>
let
    depositType =
        {
            {Text.Contains(entity, "P"), "Retail"},
            {balance >=5000000, "Business"},
            {List.ContainsAny(accounts, {"CI10","CI20"}), "Business"},
            {true, "Small Business"}
        },
    Result = try List.First(List.Select(depositType, each _{0} = true)){1}
in
    Result
