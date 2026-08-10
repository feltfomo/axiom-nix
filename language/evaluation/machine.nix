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

  finishValue =
    state: value:
    if !representation.generationMatches value then
      state
      // {
        status = "done";
        control = null;
        failure = result.internalBug result.codes.staleSemanticGeneration { };
      }
    else if state.frames == [ ] then
      state
      // {
        status = "done";
        control = null;
        terminal = value;
      }
    else
      let
        frame = builtins.head state.frames;
        rest = builtins.tail state.frames;
      in
      if frame.kind != "apply-operator" then
        state
        // {
          status = "done";
          control = null;
          failure = result.internalBug result.codes.impossibleMachineState {
            frame = frame.kind or null;
          };
        }
      else if value.kind == "closure" then
        let
          extended = representation.extendEnvironment value.environment frame.argument;
        in
        if !extended.ok then
          state
          // {
            status = "done";
            control = null;
            failure = result.internalBug result.codes.staleSemanticGeneration { };
          }
        else
          result.emit
            (
              state
              // {
                frames = rest;
                control = {
                  kind = "eval";
                  term = value.body;
                  environment = extended.value;
                  inherit (frame) depth;
                };
              }
            )
            {
              kind = "closure-application";
              level = value.environment.nextLevel;
            }
      else if value.kind == "neutral" then
        let
          extended = value // {
            spine = value.spine ++ [ frame.argument ];
          };
        in
        result.emit
          (
            state
            // {
              frames = rest;
              control = {
                kind = "return";
                value = extended;
              };
            }
          )
          {
            kind = "neutral-application";
            level = value.head.level;
            spineLength = builtins.length value.spine + 1;
          }
      else
        state
        // {
          status = "done";
          control = null;
          failure = result.internalBug result.codes.invalidSemanticValue {
            kind = value.kind or null;
          };
        };

  transition =
    limits: state:
    # fuel refusal happens before control or frame state advances
    if state.fuel >= limits.fuel then
      state
      // {
        status = "done";
        control = null;
        failure = result.exhausted "fuel" limits.fuel state.fuel;
      }
    else
      let
        fueled = state // {
          fuel = state.fuel + 1;
        };
      in
      if fueled.control.kind == "return" then
        finishValue fueled fueled.control.value
      else if fueled.control.kind != "eval" then
        fueled
        // {
          status = "done";
          control = null;
          failure = result.internalBug result.codes.impossibleMachineState {
            control = fueled.control.kind or null;
          };
        }
      else
        let
          inherit (fueled) control;
          charged = charge limits fueled control.depth;
        in
        if !charged.ok then
          fueled
          // {
            status = "done";
            control = null;
            inherit (charged) failure;
          }
        else if control.term.kind == "variable" then
          let
            found = representation.lookupEnvironment control.environment control.term.level;
            looked = result.emit charged.state {
              kind = "lookup";
              inherit (control.term) level;
            };
          in
          if !found.ok then
            looked
            // {
              status = "done";
              control = null;
              failure = result.internalBug (
                if found.reason == "generation" then
                  result.codes.staleSemanticGeneration
                else
                  result.codes.missingEnvironmentLevel
              ) found;
            }
          else if found.cell.kind == "value" then
            if !representation.generationMatches found.cell.value then
              looked
              // {
                status = "done";
                control = null;
                failure = result.internalBug result.codes.staleSemanticGeneration { };
              }
            else
              looked
              // {
                control = {
                  kind = "return";
                  inherit (found.cell) value;
                };
              }
          else if found.cell.kind == "thunk" then
            # replacing control preserves frames and keeps forcing inside the first-order machine
            if !representation.generationMatches found.cell.environment then
              looked
              // {
                status = "done";
                control = null;
                failure = result.internalBug result.codes.staleSemanticGeneration { };
              }
            else
              result.emit
                (
                  looked
                  // {
                    control = {
                      kind = "eval";
                      inherit (found.cell) term environment;
                      inherit (control) depth;
                    };
                  }
                )
                {
                  kind = "force";
                  inherit (control.term) level;
                }
          else
            looked
            // {
              status = "done";
              control = null;
              failure = result.internalBug result.codes.invalidEnvironmentCell {
                kind = found.cell.kind or null;
              };
            }
        else if control.term.kind == "lambda" then
          result.emit
            (
              charged.state
              // {
                control = {
                  kind = "return";
                  value = representation.closure control.environment control.term.body;
                };
              }
            )
            {
              kind = "closure";
              level = control.environment.nextLevel;
            }
        else if control.term.kind == "application" then
          charged.state
          // {
            control = {
              kind = "eval";
              term = control.term.function;
              inherit (control) environment;
              depth = control.depth + 1;
            };
            # the frame stores the untouched operand while control evaluates only the operator
            frames = [
              {
                kind = "apply-operator";
                argument = representation.thunkCell control.environment control.term.argument;
                depth = control.depth + 1;
              }
            ]
            ++ charged.state.frames;
          }
        else if control.term.kind == "annotation" then
          result.emit (
            charged.state
            // {
              control = {
                kind = "eval";
                term = control.term.subject;
                inherit (control) environment;
                depth = control.depth + 1;
              };
            }
          ) { kind = "annotation-erased"; }
        else
          charged.state
          // {
            status = "done";
            control = null;
            failure = result.internalBug result.codes.unknownTerm {
              kind = control.term.kind or null;
            };
          };

  runState =
    {
      state,
      limits ? { },
    }:
    let
      bounded = mergeLimits limits;
      initial =
        if
          state.status == "running"
          && state.control.kind == "eval"
          && !representation.generationMatches state.control.environment
        then
          state
          // {
            status = "done";
            control = null;
            failure = result.internalBug result.codes.staleSemanticGeneration { };
          }
        else
          state;
      states = builtins.genericClosure {
        startSet = [ (initial // { key = 0; }) ];
        operator =
          current:
          if current.status != "running" then
            [ ]
          else
            [ ((transition bounded current) // { key = current.key + 1; }) ];
      };
      final = builtins.elemAt states (builtins.length states - 1);
    in
    if final.failure != null then
      final.failure
      // {
        inherit (final) nodes fuel;
        trace = builtins.foldl' (values: value: [ value ] ++ values) [ ] final.trace;
      }
    else if final.status == "done" && final.terminal != null then
      result.machineSuccess final.terminal final
    else
      (result.internalBug result.codes.impossibleMachineState {
        inherit (final) status;
      })
      // {
        inherit (final) nodes fuel;
        trace = builtins.foldl' (values: value: [ value ] ++ values) [ ] final.trace;
      };

  initialState = root: environment: {
    status = "running";
    control = {
      kind = "eval";
      inherit environment;
      term = root;
      depth = 0;
    };
    frames = [ ];
    nodes = 0;
    fuel = 0;
    trace = [ ];
    terminal = null;
    failure = null;
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
      runState {
        state = initialState admitted.value.root (representation.initialEnvironment admitted.value.scope);
        inherit limits;
      }
    else
      result.internalBug result.codes.unknownTerm { inherit admitted; };

  inherit runState initialState transition;
}
