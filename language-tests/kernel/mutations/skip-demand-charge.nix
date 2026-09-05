{
  identity = "kernel-budget-skip-demand-charge";
  build =
    args:
    let
      production = import ../../../language/kernel/budget.nix args;
    in
    production
    // {
      protect =
        judgment: limits: costName: depth: protected:
        if costName == "demandCell" then
          protected null
        else
          production.protect judgment limits costName depth protected;
    };
}
