{ representation, result }:
let
  reverse = builtins.foldl' (xs: x: [ x ] ++ xs) [ ];
  spend =
    state:
    if state.remaining == 0 then
      {
        ok = false;
        failure = result.exhausted "nodes" state.limit state.consumed;
      }
    else
      state
      // {
        ok = true;
        remaining = state.remaining - 1;
        consumed = state.consumed + 1;
      };
  projectTerm =
    state: term:
    let
      charged = spend state;
    in
    if !charged.ok then charged else charged // { value = term; };
  projectEnvironment =
    state: environment:
    if !representation.generationMatches environment then
      {
        ok = false;
        failure = result.internalBug result.codes.staleSemanticGeneration { };
      }
    else
      let
        levels = builtins.genList (x: x) environment.nextLevel;
        folded = builtins.foldl' (
          current: level:
          if !current.ok then
            current
          else
            let
              key = representation.levelKey level;
            in
            if !builtins.hasAttr key environment.cells then
              {
                ok = false;
                failure = result.internalBug result.codes.missingEnvironmentLevel { inherit level; };
              }
            else
              let
                cell = projectCell current environment.cells.${key};
              in
              if !cell.ok then
                cell
              else
                cell
                // {
                  entries = [
                    {
                      inherit level;
                      cell = cell.value;
                    }
                  ]
                  ++ current.entries;
                }
        ) (state // { entries = [ ]; }) levels;
      in
      if !folded.ok then
        folded
      else
        folded
        // {
          value = {
            inherit (environment) nextLevel;
            cells = reverse folded.entries;
          };
        };
  projectCell =
    state: cell:
    if !representation.generationMatches cell then
      {
        ok = false;
        failure = result.internalBug result.codes.staleSemanticGeneration { };
      }
    else
      let
        charged = spend state;
      in
      if !charged.ok then
        charged
      else if cell.kind == "value" then
        let
          value = projectValue charged cell.value;
        in
        if !value.ok then
          value
        else
          value
          // {
            value = {
              kind = "value";
              inherit (value) value;
            };
          }
      else if cell.kind == "thunk" then
        let
          term = projectTerm charged cell.term;
          environment = if term.ok then projectEnvironment term cell.environment else term;
        in
        if !environment.ok then
          environment
        else
          environment
          // {
            value = {
              kind = "thunk";
              term = term.value;
              environment = environment.value;
            };
          }
      else
        {
          ok = false;
          failure = result.internalBug result.codes.invalidEnvironmentCell { kind = cell.kind or null; };
        };
  projectClosure =
    state: closure:
    # closure payloads stay inaccessible until their owning stamp is accepted
    if !representation.generationMatches closure then
      {
        ok = false;
        failure = result.internalBug result.codes.staleSemanticGeneration { };
      }
    else
      let
        charged = spend state;
        body = if charged.ok then projectTerm charged closure.body else charged;
        environment = if body.ok then projectEnvironment body closure.environment else body;
      in
      if !environment.ok then
        environment
      else
        environment
        // {
          value = {
            body = body.value;
            environment = environment.value;
          };
        };
  projectSpineItem =
    state: item:
    if !representation.generationMatches item then
      {
        ok = false;
        failure = result.internalBug result.codes.staleSemanticGeneration { };
      }
    else
      let
        charged = spend state;
      in
      if !charged.ok then
        charged
      else if item.kind == "application" then
        let
          x = projectCell charged item.argument;
        in
        if !x.ok then
          x
        else
          x
          // {
            value = {
              inherit (item) kind;
              argument = x.value;
            };
          }
      else if
        builtins.elem item.kind [
          "first-projection"
          "second-projection"
        ]
      then
        charged // { value = { inherit (item) kind; }; }
      else if item.kind == "sum-elimination" then
        let
          m = projectClosure charged item.motive;
          l = if m.ok then projectClosure m item.leftBranch else m;
          r = if l.ok then projectClosure l item.rightBranch else l;
        in
        if !r.ok then
          r
        else
          r
          // {
            value = {
              inherit (item) kind;
              motive = m.value;
              leftBranch = l.value;
              rightBranch = r.value;
            };
          }
      else if item.kind == "unit-elimination" then
        let
          m = projectClosure charged item.motive;
          c = if m.ok then projectCell m item.case else m;
        in
        if !c.ok then
          c
        else
          c
          // {
            value = {
              inherit (item) kind;
              motive = m.value;
              case = c.value;
            };
          }
      else if item.kind == "empty-elimination" then
        let
          m = projectClosure charged item.motive;
        in
        if !m.ok then
          m
        else
          m
          // {
            value = {
              inherit (item) kind;
              motive = m.value;
            };
          }
      else if item.kind == "identity-elimination" then
        let
          m = projectClosure charged item.motive;
          b = if m.ok then projectClosure m item.reflBranch else m;
        in
        if !b.ok then
          b
        else
          b
          // {
            value = {
              inherit (item) kind;
              motive = m.value;
              reflBranch = b.value;
            };
          }
      else
        {
          ok = false;
          failure = result.internalBug result.codes.invalidSemanticValue { kind = item.kind or null; };
        };
  projectCells =
    state: fields:
    builtins.foldl' (
      current: field:
      if !current.ok then
        current
      else
        let
          x = projectCell current field.value;
        in
        if !x.ok then
          x
        else
          x
          // {
            attrs = current.attrs // {
              ${field.name} = x.value;
            };
          }
    ) (state // { attrs = { }; }) fields;
  projectValue =
    state: value:
    if !representation.generationMatches value then
      {
        ok = false;
        failure = result.internalBug result.codes.staleSemanticGeneration { };
      }
    else
      let
        charged = spend state;
      in
      if !charged.ok then
        charged
      else if value.kind == "neutral" then
        let
          countValid = builtins.isInt value.spineCount && value.spineCount >= 0;
          items =
            builtins.foldl'
              (
                current: item:
                if !current.ok then
                  current
                else
                  let
                    x = projectSpineItem current item;
                  in
                  if !x.ok then
                    x
                  else
                    x
                    // {
                      entries = [ x.value ] ++ current.entries;
                      observedCount = current.observedCount + 1;
                    }
              )
              (
                charged
                // {
                  entries = [ ];
                  observedCount = 0;
                }
              )
              value.spine;
        in
        # projection validates the recorded count during the bounded spine traversal
        if !countValid then
          {
            ok = false;
            failure = result.internalBug result.codes.invalidSemanticValue { kind = "neutral-spine-count"; };
          }
        else if !items.ok then
          items
        else if items.observedCount != value.spineCount then
          {
            ok = false;
            failure = result.internalBug result.codes.invalidSemanticValue { kind = "neutral-spine-count"; };
          }
        else
          items
          // {
            value = {
              kind = "neutral";
              level = value.head.level;
              spine = items.entries;
              inherit (value) spineCount;
            };
          }
      else if value.kind == "closure" then
        let
          x = projectClosure charged value;
        in
        if !x.ok then
          x
        else
          x
          // {
            value = {
              kind = "closure";
              inherit (x.value) body environment;
            };
          }
      else if value.kind == "universe" then
        charged
        // {
          value = {
            inherit (value) kind;
            inherit (value) level;
          };
        }
      else if
        builtins.elem value.kind [
          "unit-type"
          "empty-type"
          "unit"
        ]
      then
        charged // { value = { inherit (value) kind; }; }
      else
        let
          fields =
            if value.kind == "pi" || value.kind == "sigma" then
              [
                {
                  name = "domain";
                  value = value.domain;
                }
              ]
            else if value.kind == "sum-type" then
              [
                {
                  name = "left";
                  value = value.left;
                }
                {
                  name = "right";
                  value = value.right;
                }
              ]
            else if value.kind == "pair" then
              [
                {
                  name = "first";
                  value = value.first;
                }
                {
                  name = "second";
                  value = value.second;
                }
              ]
            else if
              builtins.elem value.kind [
                "left-injection"
                "right-injection"
                "refl"
              ]
            then
              [
                {
                  name = "value";
                  inherit (value) value;
                }
              ]
            else if value.kind == "identity-type" then
              [
                {
                  name = "carrier";
                  value = value.carrier;
                }
                {
                  name = "left";
                  value = value.left;
                }
                {
                  name = "right";
                  value = value.right;
                }
              ]
            else
              [ ];
          cells = projectCells charged fields;
          family =
            if cells.ok && (value.kind == "pi" || value.kind == "sigma") then
              projectClosure cells value.codomain
            else
              cells;
        in
        if !family.ok || fields == [ ] then
          if fields == [ ] then
            {
              ok = false;
              failure = result.internalBug result.codes.invalidSemanticValue { kind = value.kind or null; };
            }
          else
            family
        else
          family
          // {
            value =
              family.attrs
              // {
                inherit (value) kind;
              }
              // (if value.kind == "pi" || value.kind == "sigma" then { codomain = family.value; } else { });
          };
  primitiveEqual = left: right: builtins.toJSON left == builtins.toJSON right;
  semanticEvents =
    trace:
    builtins.filter (
      event:
      builtins.elem event.kind [
        "charge"
        "lookup"
        "force"
        "closure"
        "closure-application"
        "neutral-application"
        "annotation-erased"
      ]
    ) trace;
in
{
  project =
    {
      value,
      limit ? 4096,
    }:
    projectValue {
      remaining = limit;
      consumed = 0;
      inherit limit;
      ok = true;
    } value;
  equal =
    {
      left,
      right,
      limit ? 4096,
    }:
    let
      a = projectValue {
        remaining = limit;
        consumed = 0;
        inherit limit;
        ok = true;
      } left;
      b = projectValue {
        remaining = limit;
        consumed = 0;
        inherit limit;
        ok = true;
      } right;
    in
    a.ok && b.ok && primitiveEqual a.value b.value;
  traceEqual = left: right: primitiveEqual (semanticEvents left) (semanticEvents right);
  inherit semanticEvents primitiveEqual;
}
