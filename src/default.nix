{ lib }:
let
  sets = import ./sets.nix { inherit lib; };
  validation = import ./validation.nix { inherit lib; };
  schema = import ./schema.nix { inherit lib validation sets; };
  identity = import ./identity.nix { inherit lib; };
  requirements = import ./requirements.nix { inherit lib sets; };
  registry = import ./registry.nix { inherit lib validation; };
  canonical = import ./canonical.nix { inherit lib; };
  phases = import ./phases.nix { inherit lib validation sets; };
  tagged = import ./tagged.nix { inherit lib; };
  types = import ./types.nix {
    inherit
      lib
      validation
      schema
      tagged
      sets
      ;
  };
in
{
  inherit
    sets
    validation
    schema
    identity
    requirements
    registry
    canonical
    phases
    tagged
    types
    ;
}
