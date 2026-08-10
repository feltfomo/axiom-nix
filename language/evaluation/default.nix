{ core }:
let
  representation = import ./representation.nix;
  result = import ./result.nix;
  direct = import ./direct.nix {
    inherit core representation result;
  };
  machine = import ./machine.nix {
    inherit core representation result;
  };
  projection = import ./projection.nix {
    inherit representation result;
  };
in
{
  inherit
    representation
    result
    direct
    machine
    projection
    ;
}
