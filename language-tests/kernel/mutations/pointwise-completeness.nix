{
  identity = "logismos-relation-pointwise-completeness";
  build =
    args:
    let
      production = import ../../../language/logismos/relation.nix args;
    in
    production
    // {
      pointwise =
        itemRelation: mismatch: left: right:
        if builtins.length left != builtins.length right then
          args.computation.fail mismatch
        else
          args.computation.traverse (
            index: itemRelation (builtins.elemAt left index) (builtins.elemAt right index)
          ) (builtins.genList (index: index) (builtins.length left - 1));
    };
}
