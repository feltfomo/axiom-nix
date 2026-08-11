let
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
        ;
      algorithms = {
        now = [
          "syntax"
          "scope"
          "levels"
          "evaluation"
          "law evidence"
        ];
        later = [
          "checking"
          "conversion"
          "quotation"
          "readback"
        ];
      };
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
      "candidate reserved"
      [ "pi value" "closure" "neutral application" ]
      "dependent function"
      [
        "binder laws"
        "beta"
      ];
  sigma =
    row [ "sigma" "pair" "first-projection" "second-projection" ] "max domain family"
      [ "pair" ]
      [ "first projection" "second projection" ] [ "projection" ] [ "congruence" ]
      "candidate reserved"
      [ "sigma value" "pair" "neutral projections" ]
      "dependent pair"
      [
        "binder laws"
        "projection"
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
      ];
  unit =
    row [ "unit-type" "unit" "unit-elimination" ] "U zero" [ "unit" ] [ "dependent unit elimination" ]
      [ "unit case" ]
      [ "congruence" ]
      "uniqueness candidate reserved"
      [ "unit type" "unit" "neutral elimination" ]
      "unit"
      [
        "sole introduction"
        "inactive motive"
      ];
  empty =
    row [ "empty-type" "empty-elimination" ] "U zero" [ ] [ "dependent empty elimination" ]
      [ ]
      [ "congruence" ]
      "none"
      [ "empty type" "neutral elimination" ]
      "empty"
      [ "no introduction" ];
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
