let
  generation = "axiom-evaluation-1";
  levelKey = toString;
  stamped = value: value // { inherit generation; };

  # generation checks force only the stamp and leave representation payloads untouched
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

  neutral =
    level:
    stamped {
      kind = "neutral";
      head = {
        kind = "level";
        inherit level;
      };
      spine = [ ];
    };

  closure =
    environment: body:
    stamped {
      kind = "closure";
      inherit environment body;
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

  # nextLevel names the new binder before the environment advances
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

  # decimal keys encode levels directly and their ordering carries no meaning
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
    generationMatches
    levelKey
    valueCell
    thunkCell
    neutral
    closure
    initialEnvironment
    extendEnvironment
    lookupEnvironment
    ;
}
