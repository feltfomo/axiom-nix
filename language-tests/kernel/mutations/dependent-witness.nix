{
  identity = "logismos-relation-dependent-witness";
  build =
    args:
    let
      production = import ../../../language/logismos/relation.nix args;
    in
    production
    // {
      dependentProduct =
        {
          leftFirst,
          rightFirst,
          firstRelation,
          secondRelation,
        }:
        args.computation.bind leftFirst (
          leftWitness:
          args.computation.bind rightFirst (
            rightWitness:
            args.computation.bind (firstRelation leftWitness rightWitness) (
              _evidence: secondRelation rightWitness leftWitness
            )
          )
        );
    };
}
