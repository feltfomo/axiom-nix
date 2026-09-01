{
  identity = "kernel-budget-skip-comparison-charge";
  build =
    args:
    let
      production = import ../../../language/kernel/budget.nix args;
    in
    production
    // {
      charge =
        judgment: limits: name: depth:
        if name == "comparison" then
          args.logismos.computation.pure null
        else
          production.charge judgment limits name depth;
    };
}
