{
  valueFields = {
    neutral = [
      "generation"
      "head"
      "kind"
      "spine"
      "spineCount"
    ];
    closure = [
      "body"
      "environment"
      "generation"
      "kind"
    ];
    universe = [
      "generation"
      "kind"
      "level"
    ];
    pi = [
      "codomain"
      "domain"
      "generation"
      "kind"
    ];
    sigma = [
      "codomain"
      "domain"
      "generation"
      "kind"
    ];
    "sum-type" = [
      "generation"
      "kind"
      "left"
      "right"
    ];
    "unit-type" = [
      "generation"
      "kind"
    ];
    "empty-type" = [
      "generation"
      "kind"
    ];
    unit = [
      "generation"
      "kind"
    ];
    pair = [
      "first"
      "generation"
      "kind"
      "second"
    ];
    "left-injection" = [
      "generation"
      "kind"
      "value"
    ];
    "right-injection" = [
      "generation"
      "kind"
      "value"
    ];
    "identity-type" = [
      "carrier"
      "generation"
      "kind"
      "left"
      "right"
    ];
    refl = [
      "generation"
      "kind"
      "value"
    ];
  };
  conversionRoles = {
    typeKinds = [
      "empty-type"
      "identity-type"
      "neutral"
      "pi"
      "sigma"
      "sum-type"
      "unit-type"
      "universe"
    ];
    valueKinds = [
      "empty-type"
      "identity-type"
      "pi"
      "sigma"
      "sum-type"
      "unit-type"
      "universe"
    ];
  };
  cellFields = {
    value = [
      "generation"
      "kind"
      "value"
    ];
    thunk = [
      "environment"
      "generation"
      "kind"
      "term"
    ];
  };
  environmentFields = [
    "cells"
    "generation"
    "nextLevel"
  ];
  headFields = [
    "kind"
    "level"
  ];
  spineItemFields = {
    application = [
      "argument"
      "generation"
      "kind"
    ];
    "first-projection" = [
      "generation"
      "kind"
    ];
    "second-projection" = [
      "generation"
      "kind"
    ];
    "sum-elimination" = [
      "generation"
      "kind"
      "leftBranch"
      "motive"
      "rightBranch"
    ];
    "unit-elimination" = [
      "case"
      "generation"
      "kind"
      "motive"
    ];
    "empty-elimination" = [
      "generation"
      "kind"
      "motive"
    ];
    "identity-elimination" = [
      "generation"
      "kind"
      "motive"
      "reflBranch"
    ];
  };
}
