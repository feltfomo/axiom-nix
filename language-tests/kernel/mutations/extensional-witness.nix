{
  identity = "logismos-relation-extensional-witness";
  build =
    args:
    let
      production = import ../../../language/logismos/relation.nix args;
    in
    production
    // {
      extensional =
        {
          witness,
          apply,
          codomain,
          relation,
        }:
        left: right:
        args.computation.bind witness (
          leftWitness:
          args.computation.bind (apply left leftWitness) (
            leftBody:
            args.computation.bind witness (
              rightWitness:
              args.computation.bind (apply right rightWitness) (
                rightBody:
                args.computation.bind witness (
                  codomainWitness:
                  args.computation.bind (codomain codomainWitness) (
                    bodyType: relation codomainWitness bodyType leftBody rightBody
                  )
                )
              )
            )
          )
        );
    };
}
