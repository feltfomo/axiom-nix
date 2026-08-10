let
  representation = import ./representation.nix;
  machine = import ./machine.nix { inherit representation; };
  operations = import ./operations.nix {
    inherit representation machine;
  };
in
{
  inherit representation machine operations;
}
