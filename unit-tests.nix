{
  inputs,
  lib,
}:
let
  language = import ./language;
  core = import ./language/core;
  legacy = import ./tests { inherit lib; };
  hostBoundary = import ./language-tests/host-boundary { inherit language; };
  coreSyntax = import ./language-tests/core-syntax { inherit language; };
  evaluation = import ./language-tests/evaluation { inherit language; };
  levels = import ./language-tests/levels { inherit core; };
  kernel = import ./language-tests/kernel { inherit language; };
  logismos = import ./language-tests/logismos { inherit lib; };
  equations = import ./language-tests/equations {
    inherit core;
    testCases = {
      "core-syntax" = coreSyntax.cases;
      levels = levels.cases;
      logismos = logismos.cases;
      kernel = kernel.evidence;
    };
  };
  foundation = import ./language-tests { inherit inputs lib; };

  fromAttrs = lib.mapAttrs' (
    name: expression:
    lib.nameValuePair "test ${name}" {
      expr = expression;
      expected = true;
    }
  );

  fromList =
    cases:
    lib.listToAttrs (
      map (case: {
        name = "test ${case.name}";
        value = {
          expr = case.pass;
          expected = true;
        };
      }) cases
    );
in
{
  legacy = fromList legacy.cases;
  language = {
    host-boundary = fromList hostBoundary.cases;
    core-syntax = fromAttrs coreSyntax.cases;
    evaluation = fromAttrs evaluation.cases;
    levels = fromAttrs levels.cases;
    kernel = fromAttrs kernel.evidence;
    logismos = fromAttrs logismos.cases;
    equations = fromAttrs equations.cases;
    foundation = fromAttrs foundation.evidence;
  };
}
