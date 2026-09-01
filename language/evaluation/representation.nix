let
  schema = import ./schema.nix;
  generation = "axiom-evaluation-2";
  levelKey = toString;
  stamped = value: value // { inherit generation; };
  # generation checks inspect the owning stamp without traversing inactive payloads
  generationMatches =
    value:
    let
      checked = builtins.tryEval (
        builtins.isAttrs value
        && value ? generation
        && builtins.isString value.generation
        && value.generation == generation
      );
    in
    checked.success && checked.value;
  valueCell =
    value:
    stamped {
      kind = "value";
      inherit value;
    };
  thunkCell =
    environment: term:
    stamped {
      kind = "thunk";
      inherit environment term;
    };
  spineItem = stamped;
  neutral =
    level:
    stamped {
      kind = "neutral";
      head = {
        kind = "level";
        inherit level;
      };
      spine = [ ];
      spineCount = 0;
    };
  # newest-first storage makes elimination extension constant time while projection restores semantic order
  extendNeutral =
    value: item:
    value
    // {
      spine = [ (spineItem item) ] ++ value.spine;
      spineCount = value.spineCount + 1;
    };
  closure =
    environment: body:
    stamped {
      kind = "closure";
      inherit environment body;
    };
  universe =
    level:
    stamped {
      kind = "universe";
      inherit level;
    };
  pi =
    domain: codomain:
    stamped {
      kind = "pi";
      inherit domain codomain;
    };
  sigma =
    domain: codomain:
    stamped {
      kind = "sigma";
      inherit domain codomain;
    };
  sumType =
    left: right:
    stamped {
      kind = "sum-type";
      inherit left right;
    };
  unitType = stamped { kind = "unit-type"; };
  emptyType = stamped { kind = "empty-type"; };
  unit = stamped { kind = "unit"; };
  pair =
    first: second:
    stamped {
      kind = "pair";
      inherit first second;
    };
  leftInjection =
    value:
    stamped {
      kind = "left-injection";
      inherit value;
    };
  rightInjection =
    value:
    stamped {
      kind = "right-injection";
      inherit value;
    };
  identityType =
    carrier: left: right:
    stamped {
      kind = "identity-type";
      inherit carrier left right;
    };
  refl =
    value:
    stamped {
      kind = "refl";
      inherit value;
    };
  initialEnvironment =
    scope:
    stamped {
      nextLevel = scope;
      cells = builtins.listToAttrs (
        builtins.genList (level: {
          name = levelKey level;
          value = valueCell (neutral level);
        }) scope
      );
    };
  # the environment names each binder with the current absolute next level
  extendEnvironment =
    environment: cell:
    if !generationMatches environment || !generationMatches cell then
      {
        ok = false;
        reason = "generation";
      }
    else
      {
        ok = true;
        value = stamped {
          nextLevel = environment.nextLevel + 1;
          cells = environment.cells // {
            ${levelKey environment.nextLevel} = cell;
          };
        };
      };
  lookupEnvironment =
    environment: level:
    let
      key = levelKey level;
    in
    if !generationMatches environment then
      {
        ok = false;
        reason = "generation";
      }
    else if builtins.hasAttr key environment.cells then
      let
        cell = environment.cells.${key};
      in
      if generationMatches cell then
        {
          ok = true;
          inherit cell;
        }
      else
        {
          ok = false;
          reason = "generation";
        }
    else
      {
        ok = false;
        reason = "missing-level";
        inherit level;
        inherit (environment) nextLevel;
      };
in
{
  inherit
    generation
    schema
    generationMatches
    levelKey
    valueCell
    thunkCell
    spineItem
    neutral
    extendNeutral
    closure
    universe
    pi
    sigma
    sumType
    unitType
    emptyType
    unit
    pair
    leftInjection
    rightInjection
    identityType
    refl
    initialEnvironment
    extendEnvironment
    lookupEnvironment
    ;
}
