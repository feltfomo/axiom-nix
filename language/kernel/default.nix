{ core }:
let
  evaluation = import ../evaluation { inherit core; };
  representation = import ./representation.nix { inherit evaluation; };
  result = import ./result.nix { inherit representation core; };
  context = import ./context.nix { inherit evaluation representation result; };
  readback = import ./readback.nix {
    inherit
      core
      evaluation
      representation
      result
      context
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
      ;
  };
  checking = import ./checking.nix {
    inherit
      core
      evaluation
      representation
      result
      context
      readback
      conversion
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
