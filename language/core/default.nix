let
  representation = import ./representation.nix;
  levels = import ./levels.nix { inherit (representation) limits; };
  machine = import ./machine.nix { inherit representation levels; };
  operations = import ./operations.nix { inherit representation machine; };
  ruleFamilies = import ./rule-families.nix;
in
{
  inherit
    representation
    levels
    machine
    operations
    ruleFamilies
    ;
}
