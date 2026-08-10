{
  core,
  representation,
  result,
}:
let
  mergeLimits = supplied: result.limits // supplied;

  charge =
    limits: state: depth:
    if depth > limits.depth then
      {
        ok = false;
        failure = result.exhausted "depth" limits.depth state.nodes;
      }
    else if state.nodes >= limits.nodes then
      {
        ok = false;
        failure = result.exhausted "nodes" limits.nodes state.nodes;
      }
    else
      {
        ok = true;
        state = result.emit (state // { nodes = state.nodes + 1; }) {
          kind = "charge";
          dimension = "node";
          consumed = state.nodes + 1;
          inherit depth;
        };
      };

  runRoot =
    {
      root,
      environment,
      limits ? { },
    }:
    let
      bounded = mergeLimits limits;

      evaluate =
        state: currentEnvironment: depth: term:
        let
          charged = charge bounded state depth;
        in
        if !charged.ok then
          {
            ok = false;
            inherit (charged) failure;
            inherit state;
          }
        else if term.kind == "variable" then
          let
            found = representation.lookupEnvironment currentEnvironment term.level;
            looked = result.emit charged.state {
              kind = "lookup";
              inherit (term) level;
            };
          in
          if !found.ok then
            {
              ok = false;
              failure = result.internalBug (
                if found.reason == "generation" then
                  result.codes.staleSemanticGeneration
                else
                  result.codes.missingEnvironmentLevel
              ) found;
              state = looked;
            }
          else if found.cell.kind == "value" then
            if !representation.generationMatches found.cell.value then
              {
                ok = false;
                failure = result.internalBug result.codes.staleSemanticGeneration { };
                state = looked;
              }
            else
              {
                ok = true;
                inherit (found.cell) value;
                state = looked;
              }
          else if found.cell.kind == "thunk" then
            # forcing reuses the stored term and environment without updating the cell
            if !representation.generationMatches found.cell.environment then
              {
                ok = false;
                failure = result.internalBug result.codes.staleSemanticGeneration { };
                state = looked;
              }
            else
              evaluate (result.emit looked {
                kind = "force";
                inherit (term) level;
              }) found.cell.environment depth found.cell.term
          else
            {
              ok = false;
              failure = result.internalBug result.codes.invalidEnvironmentCell {
                kind = found.cell.kind or null;
              };
              state = looked;
            }
        else if term.kind == "lambda" then
          {
            ok = true;
            value = representation.closure currentEnvironment term.body;
            state = result.emit charged.state {
              kind = "closure";
              level = currentEnvironment.nextLevel;
            };
          }
        else if term.kind == "application" then
          let
            operator = evaluate charged.state currentEnvironment (depth + 1) term.function;
          in
          if !operator.ok then
            operator
          else
            apply operator.state operator.value (representation.thunkCell currentEnvironment term.argument) (
              depth + 1
            )
        else if term.kind == "annotation" then
          # admission already validated both children and evaluation never revisits the erased child
          evaluate (result.emit charged.state { kind = "annotation-erased"; }) currentEnvironment (
            depth + 1
          ) term.subject
        else
          {
            ok = false;
            failure = result.internalBug result.codes.unknownTerm {
              kind = term.kind or null;
            };
            inherit (charged) state;
          };

      apply =
        state: function: argument: depth:
        if !representation.generationMatches function then
          {
            ok = false;
            failure = result.internalBug result.codes.staleSemanticGeneration { };
            inherit state;
          }
        else if function.kind == "closure" then
          let
            extended = representation.extendEnvironment function.environment argument;
          in
          if !extended.ok then
            {
              ok = false;
              failure = result.internalBug result.codes.staleSemanticGeneration { };
              inherit state;
            }
          else
            evaluate (result.emit state {
              kind = "closure-application";
              level = function.environment.nextLevel;
            }) extended.value depth function.body
        else if function.kind == "neutral" then
          {
            ok = true;
            value = function // {
              spine = function.spine ++ [ argument ];
            };
            state = result.emit state {
              kind = "neutral-application";
              level = function.head.level;
              spineLength = builtins.length function.spine + 1;
            };
          }
        else
          {
            ok = false;
            failure = result.internalBug result.codes.invalidSemanticValue {
              kind = function.kind or null;
            };
            inherit state;
          };

      initial = {
        nodes = 0;
        trace = [ ];
      };
      evaluated =
        if !representation.generationMatches environment then
          {
            ok = false;
            failure = result.internalBug result.codes.staleSemanticGeneration { };
            state = initial;
          }
        else
          evaluate initial environment 0 root;
    in
    if evaluated.ok then
      result.success evaluated.value evaluated.state
    else
      evaluated.failure
      // {
        nodes = evaluated.state.nodes;
        trace = builtins.foldl' (values: value: [ value ] ++ values) [ ] evaluated.state.trace;
      };
in
{
  evaluate =
    {
      envelope,
      limits ? { },
    }:
    let
      admitted = core.operations.admitted envelope;
    in
    if admitted.ok then
      runRoot {
        root = admitted.value.root;
        environment = representation.initialEnvironment admitted.value.scope;
        inherit limits;
      }
    else
      result.internalBug result.codes.unknownTerm { inherit admitted; };

  inherit runRoot;

}
