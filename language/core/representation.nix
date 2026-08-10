let
  generation = "axiom-core-syntax-1";
  limits = {
    nodes = 256;
    depth = 64;
    locationComponents = 16;
  };
in
{
  inherit generation limits;

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

  envelope = scope: root: metadata: {
    inherit
      generation
      scope
      root
      metadata
      ;
  };
}
