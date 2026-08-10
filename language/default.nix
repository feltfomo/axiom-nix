let
  generation = "axiom-language-1";
  boundary = import ./boundary;
  core = import ./core;
  syntax = import ./syntax {
    inherit core;
    inherit (boundary) result;
  };
in
{
  inherit generation boundary syntax;
}
