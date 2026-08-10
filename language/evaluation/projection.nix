{ representation, result }:
let
  reverse = builtins.foldl' (values: value: [ value ] ++ values) [ ];
  spend =
    state:
    if state.remaining == 0 then
      {
        ok = false;
        failure = result.exhausted "nodes" state.limit state.consumed;
      }
    else
      {
        ok = true;
        remaining = state.remaining - 1;
        consumed = state.consumed + 1;
        inherit (state) limit;
      };

  projectTerm =
    state: term:
    let
      charged = spend state;
    in
    if !charged.ok then
      charged
    else if term.kind == "variable" then
      charged
      // {
        value = {
          kind = "variable";
          inherit (term) level;
        };
      }
    else if term.kind == "lambda" then
      let
        body = projectTerm charged term.body;
      in
      if !body.ok then
        body
      else
        body
        // {
          value = {
            kind = "lambda";
            body = body.value;
          };
        }
    else if term.kind == "application" then
      let
        function = projectTerm charged term.function;
        argument = if function.ok then projectTerm function term.argument else function;
      in
      if !argument.ok then
        argument
      else
        argument
        // {
          value = {
            kind = "application";
            function = function.value;
            argument = argument.value;
          };
        }
    else
      let
        subject = projectTerm charged term.subject;
        annotation = if subject.ok then projectTerm subject term.annotation else subject;
      in
      if !annotation.ok then
        annotation
      else
        annotation
        // {
          value = {
            kind = "annotation";
            subject = subject.value;
            annotation = annotation.value;
          };
        };

  # environment projection visits every recorded level and cannot witness runtime laziness
  projectEnvironment =
    state: environment:
    if !representation.generationMatches environment then
      {
        ok = false;
        failure = result.internalBug result.codes.staleSemanticGeneration { };
      }
    else
      let
        levels = builtins.genList (level: level) environment.nextLevel;
        collected = builtins.foldl' (
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
                failure = result.internalBug result.codes.missingEnvironmentLevel {
                  inherit level;
                  inherit (environment) nextLevel;
                };
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
      if !collected.ok then
        collected
      else
        collected
        // {
          value = {
            inherit (environment) nextLevel;
            cells = reverse collected.entries;
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
      else
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
          };

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
          collected = builtins.foldl' (
            current: cell:
            if !current.ok then
              current
            else
              let
                projected = projectCell current cell;
              in
              if !projected.ok then
                projected
              else
                projected
                // {
                  entries = [ projected.value ] ++ current.entries;
                }
          ) (charged // { entries = [ ]; }) value.spine;
        in
        if !collected.ok then
          collected
        else
          collected
          // {
            value = {
              kind = "neutral";
              level = value.head.level;
              spine = reverse collected.entries;
            };
          }
      else
        let
          body = projectTerm charged value.body;
          environment = if body.ok then projectEnvironment body value.environment else body;
        in
        if !environment.ok then
          environment
        else
          environment
          // {
            value = {
              kind = "closure";
              body = body.value;
              environment = environment.value;
            };
          };

  primitiveEqual =
    left: right:
    builtins.typeOf left == builtins.typeOf right
    && (
      if builtins.isAttrs left then
        let
          leftNames = builtins.attrNames left;
          rightNames = builtins.attrNames right;
        in
        builtins.length leftNames == builtins.length rightNames
        && builtins.all (
          name: builtins.hasAttr name right && primitiveEqual left.${name} right.${name}
        ) leftNames
      else if builtins.isList left then
        builtins.length left == builtins.length right
        && builtins.all (index: primitiveEqual (builtins.elemAt left index) (builtins.elemAt right index)) (
          builtins.genList (index: index) (builtins.length left)
        )
      else
        left == right
    );

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
      limit ? 1024,
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
      limit ? 1024,
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
