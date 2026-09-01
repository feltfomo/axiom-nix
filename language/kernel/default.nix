{ core }:
let
  logismos = import ../logismos;
  evaluation = import ../evaluation { inherit core; };
  representation = import ./representation.nix { inherit evaluation; };
  result = import ./result.nix { inherit representation core; };
  budget = import ./budget.nix { inherit logismos representation result; };
  context = import ./context.nix {
    inherit
      evaluation
      representation
      result
      budget
      logismos
      ;
  };
  semantic = import ./semantic.nix {
    inherit
      core
      evaluation
      representation
      result
      budget
      logismos
      ;
  };
  neutralTransition = import ./neutral-transition.nix {
    inherit
      evaluation
      representation
      result
      context
      semantic
      budget
      logismos
      ;
  };
  readback = import ./readback.nix {
    inherit
      core
      evaluation
      representation
      result
      context
      budget
      semantic
      neutralTransition
      logismos
      ;
  };
  conversion = import ./conversion.nix {
    inherit
      core
      evaluation
      representation
      result
      context
      readback
      semantic
      budget
      neutralTransition
      logismos
      ;
  };
  checking = import ./checking.nix {
    inherit
      core
      evaluation
      representation
      result
      context
      conversion
      semantic
      budget
      logismos
      ;
  };
in
{
  inherit (representation) generation limits;
  inherit (checking)
    checkContext
    form
    infer
    check
    ;
  inherit (conversion) convertTypes convertTerms oracle;
  inherit (readback) quote quoteType normalize;
}
