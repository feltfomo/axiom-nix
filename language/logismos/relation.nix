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

  # the first values choose the relation for the dependent fields
  dependentProduct =
    firstRelation: secondRelation: left: right:
    bind (firstRelation left.first right.first) (
      _firstEvidence: secondRelation left.first right.first left.second right.second
    );

  extensional =
    {
      fresh,
      apply,
      relation,
    }:
    left: right: relation (apply left fresh) (apply right fresh);

  pointwise =
    itemRelation: mismatch: left: right:
    if builtins.length left != builtins.length right then
      fail mismatch
    else
      traverse (index: itemRelation (builtins.elemAt left index) (builtins.elemAt right index)) (
        builtins.genList (index: index) (builtins.length left)
      );
}
