{ computation }:
let
  inherit (computation)
    bind
    fail
    traverse
    ;
in
{
  # left runs first because relation effects follow premise order
  product =
    leftRelation: rightRelation: left: right:
    bind (leftRelation (builtins.elemAt left 0) (builtins.elemAt right 0)) (
      _leftEvidence: rightRelation (builtins.elemAt left 1) (builtins.elemAt right 1)
    );

  sum =
    {
      classify,
      leftRelation,
      rightRelation,
      mismatch,
    }:
    left: right:
    let
      leftKind = classify left;
      rightKind = classify right;
    in
    if leftKind == "left" && rightKind == "left" then
      leftRelation left.value right.value
    else if leftKind == "right" && rightKind == "right" then
      rightRelation left.value right.value
    else
      fail mismatch;

  # retained witnesses choose the dependent relation after their comparison succeeds
  dependentProduct =
    {
      leftFirst,
      rightFirst,
      firstRelation,
      secondRelation,
    }:
    bind leftFirst (
      leftWitness:
      bind rightFirst (
        rightWitness:
        bind (firstRelation leftWitness rightWitness) (
          _firstEvidence: secondRelation leftWitness rightWitness
        )
      )
    );

  # one witness supplies both applications and the dependent codomain
  extensional =
    {
      witness,
      apply,
      codomain,
      relation,
    }:
    left: right:
    bind witness (
      retained:
      bind (apply left retained) (
        leftBody:
        bind (apply right retained) (
          rightBody: bind (codomain retained) (bodyType: relation retained bodyType leftBody rightBody)
        )
      )
    );

  pointwise =
    itemRelation: mismatch: left: right:
    if builtins.length left != builtins.length right then
      fail mismatch
    else
      traverse (index: itemRelation (builtins.elemAt left index) (builtins.elemAt right index)) (
        builtins.genList (index: index) (builtins.length left)
      );
}
