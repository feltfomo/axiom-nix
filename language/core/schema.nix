let
  row = kind: fields: children: binders: rebuild: {
    inherit
      kind
      fields
      children
      binders
      rebuild
      ;
  };
  # child order fixes traversal order and each binder increment applies only to its matching child
  rows = [
    (row "variable" [ "kind" "level" ] [ ] [ ] null)
    (row "lambda" [ "body" "kind" ] [ "body" ] [ 1 ] (r: v: r.lambda (builtins.elemAt v 0)))
    (row "application" [ "argument" "function" "kind" ] [ "function" "argument" ] [ 0 0 ] (
      r: v: r.application (builtins.elemAt v 0) (builtins.elemAt v 1)
    ))
    (row "annotation" [ "annotation" "kind" "subject" ] [ "subject" "annotation" ] [ 0 0 ] (
      r: v: r.annotation (builtins.elemAt v 0) (builtins.elemAt v 1)
    ))
    (row "universe" [ "kind" "level" ] [ ] [ ] null)
    (row "pi" [ "codomain" "domain" "kind" ] [ "domain" "codomain" ] [ 0 1 ] (
      r: v: r.pi (builtins.elemAt v 0) (builtins.elemAt v 1)
    ))
    (row "sigma" [ "codomain" "domain" "kind" ] [ "domain" "codomain" ] [ 0 1 ] (
      r: v: r.sigma (builtins.elemAt v 0) (builtins.elemAt v 1)
    ))
    (row "sum-type" [ "kind" "left" "right" ] [ "left" "right" ] [ 0 0 ] (
      r: v: r.sumType (builtins.elemAt v 0) (builtins.elemAt v 1)
    ))
    (row "unit-type" [ "kind" ] [ ] [ ] null)
    (row "unit" [ "kind" ] [ ] [ ] null)
    (row "empty-type" [ "kind" ] [ ] [ ] null)
    (row "pair" [ "first" "kind" "second" ] [ "first" "second" ] [ 0 0 ] (
      r: v: r.pair (builtins.elemAt v 0) (builtins.elemAt v 1)
    ))
    (row "first-projection" [ "kind" "pair" ] [ "pair" ] [ 0 ] (
      r: v: r.firstProjection (builtins.elemAt v 0)
    ))
    (row "second-projection" [ "kind" "pair" ] [ "pair" ] [ 0 ] (
      r: v: r.secondProjection (builtins.elemAt v 0)
    ))
    (row "left-injection" [ "kind" "value" ] [ "value" ] [ 0 ] (
      r: v: r.leftInjection (builtins.elemAt v 0)
    ))
    (row "right-injection" [ "kind" "value" ] [ "value" ] [ 0 ] (
      r: v: r.rightInjection (builtins.elemAt v 0)
    ))
    (row "sum-elimination" [ "kind" "leftBranch" "motive" "rightBranch" "scrutinee" ]
      [ "scrutinee" "motive" "leftBranch" "rightBranch" ]
      [ 0 1 1 1 ]
      (
        r: v:
        r.sumElimination (builtins.elemAt v 0) (builtins.elemAt v 1) (builtins.elemAt v 2) (
          builtins.elemAt v 3
        )
      )
    )
    (row "unit-elimination" [ "case" "kind" "motive" "scrutinee" ]
      [ "scrutinee" "motive" "case" ]
      [ 0 1 0 ]
      (r: v: r.unitElimination (builtins.elemAt v 0) (builtins.elemAt v 1) (builtins.elemAt v 2))
    )
    (row "empty-elimination" [ "kind" "motive" "scrutinee" ] [ "scrutinee" "motive" ] [ 0 1 ] (
      r: v: r.emptyElimination (builtins.elemAt v 0) (builtins.elemAt v 1)
    ))
    (row "identity-type" [ "carrier" "kind" "left" "right" ] [ "carrier" "left" "right" ] [ 0 0 0 ] (
      r: v: r.identityType (builtins.elemAt v 0) (builtins.elemAt v 1) (builtins.elemAt v 2)
    ))
    (row "refl" [ "kind" "value" ] [ "value" ] [ 0 ] (r: v: r.refl (builtins.elemAt v 0)))
    (row "identity-elimination" [ "kind" "motive" "reflBranch" "scrutinee" ]
      [ "scrutinee" "motive" "reflBranch" ]
      [ 0 3 1 ]
      (r: v: r.identityElimination (builtins.elemAt v 0) (builtins.elemAt v 1) (builtins.elemAt v 2))
    )
  ];
  byKind = builtins.listToAttrs (
    map (entry: {
      name = entry.kind;
      value = entry;
    }) rows
  );
in
{
  inherit rows byKind;
  termKinds = map (entry: entry.kind) rows;
}
