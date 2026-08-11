let
  generation = "axiom-core-syntax-2";
  limits = {
    nodes = 256;
    depth = 64;
    locationComponents = 16;
  };
  levelZero = {
    kind = "zero";
  };
  levelSuc = level: {
    kind = "suc";
    inherit level;
  };
  levelMax = left: right: {
    kind = "max";
    inherit left right;
  };
  variable = level: {
    kind = "variable";
    inherit level;
  };
  lambda = body: {
    kind = "lambda";
    inherit body;
  };
  application = function: argument: {
    kind = "application";
    inherit function argument;
  };
  annotation = subject: annotation: {
    kind = "annotation";
    inherit subject annotation;
  };
  universe = level: {
    kind = "universe";
    inherit level;
  };
  pi = domain: codomain: {
    kind = "pi";
    inherit domain codomain;
  };
  sigma = domain: codomain: {
    kind = "sigma";
    inherit domain codomain;
  };
  sumType = left: right: {
    kind = "sum-type";
    inherit left right;
  };
  unitType = {
    kind = "unit-type";
  };
  unit = {
    kind = "unit";
  };
  emptyType = {
    kind = "empty-type";
  };
  pair = first: second: {
    kind = "pair";
    inherit first second;
  };
  firstProjection = pair: {
    kind = "first-projection";
    inherit pair;
  };
  secondProjection = pair: {
    kind = "second-projection";
    inherit pair;
  };
  leftInjection = value: {
    kind = "left-injection";
    inherit value;
  };
  rightInjection = value: {
    kind = "right-injection";
    inherit value;
  };
  sumElimination = scrutinee: motive: leftBranch: rightBranch: {
    kind = "sum-elimination";
    inherit
      scrutinee
      motive
      leftBranch
      rightBranch
      ;
  };
  unitElimination = scrutinee: motive: case: {
    kind = "unit-elimination";
    inherit scrutinee motive case;
  };
  emptyElimination = scrutinee: motive: {
    kind = "empty-elimination";
    inherit scrutinee motive;
  };
  identityType = carrier: left: right: {
    kind = "identity-type";
    inherit carrier left right;
  };
  refl = value: {
    kind = "refl";
    inherit value;
  };
  identityElimination = scrutinee: motive: reflBranch: {
    kind = "identity-elimination";
    inherit scrutinee motive reflBranch;
  };
  envelope = scope: root: metadata: {
    inherit
      generation
      scope
      root
      metadata
      ;
  };
in
{
  inherit
    generation
    limits
    levelZero
    levelSuc
    levelMax
    variable
    lambda
    application
    annotation
    universe
    pi
    sigma
    sumType
    unitType
    unit
    emptyType
    pair
    firstProjection
    secondProjection
    leftInjection
    rightInjection
    sumElimination
    unitElimination
    emptyElimination
    identityType
    refl
    identityElimination
    envelope
    ;
  levelKinds = [
    "zero"
    "suc"
    "max"
  ];
  termKinds = [
    "variable"
    "lambda"
    "application"
    "annotation"
    "universe"
    "pi"
    "sigma"
    "sum-type"
    "unit-type"
    "unit"
    "empty-type"
    "pair"
    "first-projection"
    "second-projection"
    "left-injection"
    "right-injection"
    "sum-elimination"
    "unit-elimination"
    "empty-elimination"
    "identity-type"
    "refl"
    "identity-elimination"
  ];
}
