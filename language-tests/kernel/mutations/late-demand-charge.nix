{
  identity = "kernel-budget-late-demand-charge";
  build =
    args:
    let
      production = import ../../../language/kernel/budget.nix args;
      inherit (args.logismos) computation;
    in
    production
    // {
      protect =
        judgment: limits: costName: depth: protected:
        if costName == "demandCell" then
          computation.bind (protected null) (
            value: computation.map (_charged: value) (production.chargeNamed judgment limits costName depth)
          )
        else
          production.protect judgment limits costName depth protected;
    };
}
