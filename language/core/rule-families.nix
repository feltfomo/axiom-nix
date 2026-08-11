let
  ownership = {
    syntax = "core syntax";
    scope = "core operations";
    levels = "level normalization";
    evaluation = "weak-head evaluation";
    formation = "private kernel";
    checking = "private kernel";
    conversion = "private kernel";
    quotation = "private kernel";
    readback = "private kernel";
    lawEvidence = "language test gate";
  };
  row =
    syntax: formation: introduction: elimination: computation: equality: etaStatus: semantics: diagnostics: laws: {
      inherit
        syntax
        formation
        introduction
        elimination
        computation
        equality
        etaStatus
        semantics
        diagnostics
        laws
        ownership
        ;
    };
in
{
  universe =
    row [ "universe" ] "U l lives in U (suc l)" [ ] [ ] [ "level normalization" ] [ "level congruence" ]
      "not applicable"
      [ "universe value" ]
      "universe"
      [
        "no self membership"
        "no cumulativity"
      ];
  pi =
    row [ "pi" "lambda" "application" ] "max domain family" [ "lambda" ] [ "application" ]
      [ "beta" ]
      [ "congruence" ]
      "extensional eta"
      [ "pi value" "closure" "neutral application" ]
      "dependent function"
      [
        "binder laws"
        "beta"
        "eta"
      ];
  sigma =
    row [ "sigma" "pair" "first-projection" "second-projection" ] "max domain family"
      [ "pair" ]
      [ "first projection" "second projection" ] [ "projection" ] [ "congruence" ]
      "surjective-pair eta"
      [ "sigma value" "pair" "neutral projections" ]
      "dependent pair"
      [
        "binder laws"
        "projection"
        "eta"
      ];
  sum =
    row [ "sum-type" "left-injection" "right-injection" "sum-elimination" ] "max components"
      [ "left" "right" ]
      [ "dependent case" ] [ "left case" "right case" ] [ "congruence" ]
      "none"
      [ "sum value" "injections" "neutral case" ]
      "binary sum"
      [
        "branch computation"
        "inactive motive"
        "no eta"
      ];
  unit =
    row [ "unit-type" "unit" "unit-elimination" ] "U zero" [ "unit" ] [ "dependent unit elimination" ]
      [ "unit case" ]
      [ "congruence" ]
      "typed uniqueness"
      [ "unit type" "unit" "neutral elimination" ]
      "unit"
      [
        "sole introduction"
        "inactive motive"
        "uniqueness"
      ];
  empty =
    row [ "empty-type" "empty-elimination" ] "U zero" [ ] [ "dependent empty elimination" ]
      [ ]
      [ "congruence" ]
      "none"
      [ "empty type" "neutral elimination" ]
      "empty"
      [
        "no introduction"
        "no eta"
      ];
  identity =
    (row [ "identity-type" "refl" "identity-elimination" ] "carrier level" [ "refl" ] [ "general J" ]
      [ "J on refl" ]
      [ "congruence" ]
      "none"
      [ "identity value" "refl" "neutral J" ]
      "identity"
      [
        "general J binder order"
        "no equality reflection"
        "no eta"
      ]
    )
    // {
      binderOrder = {
        motive = [
          "source"
          "target"
          "evidence"
        ];
        reflBranch = [ "witness" ];
      };
      rejectedSyntax = "based J";
      excluded = [
        "equality reflection"
        "function extensionality"
        "UIP"
        "proof irrelevance"
        "postulates"
      ];
    };
}
