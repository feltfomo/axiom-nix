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
  fail =
    state: code: context:
    state
    // {
      status = "done";
      control = null;
      failure = result.internalBug code context;
    };
  return =
    state: value:
    state
    // {
      control = {
        kind = "return";
        inherit value;
      };
    };
  eval =
    state: environment: term: depth:
    if !representation.generationMatches environment then
      fail state result.codes.staleSemanticGeneration { }
    else
      state
      // {
        control = {
          kind = "eval";
          inherit environment term depth;
        };
      };
  demandCell =
    state: cell: depth:
    if !representation.generationMatches cell then
      fail state result.codes.staleSemanticGeneration { }
    else if cell.kind == "value" then
      if representation.generationMatches cell.value then
        return state cell.value
      else
        fail state result.codes.staleSemanticGeneration { }
    else if cell.kind == "thunk" then
      if representation.generationMatches cell.environment then
        eval state cell.environment cell.term depth
      else
        fail state result.codes.staleSemanticGeneration { }
    else
      fail state result.codes.invalidEnvironmentCell { kind = cell.kind or null; };
  applyValue =
    state: function: argument: depth:
    if !representation.generationMatches argument then
      fail state result.codes.staleSemanticGeneration { }
    else if !representation.generationMatches function then
      fail state result.codes.staleSemanticGeneration { }
    else if function.kind == "closure" then
      let
        extended = representation.extendEnvironment function.environment argument;
      in
      if extended.ok then
        eval (result.emit state {
          kind = "closure-application";
          level = function.environment.nextLevel;
        }) extended.value function.body depth
      else
        fail state result.codes.staleSemanticGeneration { }
    else if function.kind == "neutral" then
      return
        (result.emit state {
          kind = "neutral-application";
          level = function.head.level;
          spineLength = function.spineCount + 1;
        })
        (
          representation.extendNeutral function {
            kind = "application";
            inherit argument;
          }
        )
    else
      fail state result.codes.invalidSemanticValue { kind = function.kind or null; };

  finishValue =
    state: value:
    if !representation.generationMatches value then
      fail state result.codes.staleSemanticGeneration { }
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
        resumed = state // {
          frames = rest;
        };
      in
      # frame environments are checked before current wrappers can capture them
      if frame ? environment && !representation.generationMatches frame.environment then
        fail resumed result.codes.staleSemanticGeneration { }
      else if frame.kind == "apply-operator" then
        applyValue resumed value frame.argument frame.depth
      else if frame.kind == "first-projection-subject" then
        if value.kind == "pair" then
          demandCell resumed value.first frame.depth
        else if value.kind == "neutral" then
          return resumed (representation.extendNeutral value { kind = "first-projection"; })
        else
          fail resumed result.codes.invalidSemanticValue { kind = value.kind or null; }
      else if frame.kind == "second-projection-subject" then
        if value.kind == "pair" then
          demandCell resumed value.second frame.depth
        else if value.kind == "neutral" then
          return resumed (representation.extendNeutral value { kind = "second-projection"; })
        else
          fail resumed result.codes.invalidSemanticValue { kind = value.kind or null; }
      else if frame.kind == "sum-elimination-scrutinee" then
        # raw branches remain inactive until the returned scrutinee selects one
        if value.kind == "left-injection" || value.kind == "right-injection" then
          applyValue resumed (representation.closure frame.environment (
            if value.kind == "left-injection" then frame.leftBranch else frame.rightBranch
          )) value.value frame.depth
        else if value.kind == "neutral" then
          return resumed (
            representation.extendNeutral value {
              kind = "sum-elimination";
              motive = representation.closure frame.environment frame.motive;
              leftBranch = representation.closure frame.environment frame.leftBranch;
              rightBranch = representation.closure frame.environment frame.rightBranch;
            }
          )
        else
          fail resumed result.codes.invalidSemanticValue { kind = value.kind or null; }
      else if frame.kind == "unit-elimination-scrutinee" then
        if value.kind == "unit" then
          eval resumed frame.environment frame.case frame.depth
        else if value.kind == "neutral" then
          return resumed (
            representation.extendNeutral value {
              kind = "unit-elimination";
              motive = representation.closure frame.environment frame.motive;
              case = representation.thunkCell frame.environment frame.case;
            }
          )
        else
          fail resumed result.codes.invalidSemanticValue { kind = value.kind or null; }
      else if frame.kind == "empty-elimination-scrutinee" then
        if value.kind == "neutral" then
          return resumed (
            representation.extendNeutral value {
              kind = "empty-elimination";
              motive = representation.closure frame.environment frame.motive;
            }
          )
        else
          fail resumed result.codes.invalidSemanticValue { kind = value.kind or null; }
      else if frame.kind == "identity-elimination-scrutinee" then
        # the refl path supplies only its witness while motive syntax stays untouched
        if value.kind == "refl" then
          applyValue resumed (representation.closure frame.environment frame.reflBranch) value.value
            frame.depth
        else if value.kind == "neutral" then
          return resumed (
            representation.extendNeutral value {
              kind = "identity-elimination";
              motive = representation.closure frame.environment frame.motive;
              reflBranch = representation.closure frame.environment frame.reflBranch;
            }
          )
        else
          fail resumed result.codes.invalidSemanticValue { kind = value.kind or null; }
      else
        fail resumed result.codes.impossibleMachineState { frame = frame.kind or null; };

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
        fail fueled result.codes.impossibleMachineState { control = fueled.control.kind or null; }
      else if !representation.generationMatches fueled.control.environment then
        fail fueled result.codes.staleSemanticGeneration { }
      else
        let
          c = fueled.control;
          charged = charge limits fueled c.depth;
          thunk = child: representation.thunkCell c.environment child;
          push =
            frame: term:
            charged.state
            // {
              frames = [ frame ] ++ charged.state.frames;
              control = {
                kind = "eval";
                inherit (c) environment;
                inherit term;
                depth = c.depth + 1;
              };
            };
        in
        if !charged.ok then
          fueled
          // {
            status = "done";
            control = null;
            inherit (charged) failure;
          }
        else if c.term.kind == "variable" then
          let
            found = representation.lookupEnvironment c.environment c.term.level;
            looked = result.emit charged.state {
              kind = "lookup";
              inherit (c.term) level;
            };
          in
          if !found.ok then
            fail looked (
              if found.reason == "generation" then
                result.codes.staleSemanticGeneration
              else
                result.codes.missingEnvironmentLevel
            ) found
          else
            demandCell (
              if found.cell.kind == "thunk" then
                result.emit looked {
                  kind = "force";
                  inherit (c.term) level;
                }
              else
                looked
            ) found.cell c.depth
        else if c.term.kind == "lambda" then
          return (result.emit charged.state {
            kind = "closure";
            level = c.environment.nextLevel;
          }) (representation.closure c.environment c.term.body)
        else if c.term.kind == "application" then
          push {
            kind = "apply-operator";
            argument = thunk c.term.argument;
            depth = c.depth + 1;
          } c.term.function
        else if c.term.kind == "annotation" then
          eval (result.emit charged.state { kind = "annotation-erased"; }) c.environment c.term.subject (
            c.depth + 1
          )
        else if c.term.kind == "universe" then
          return charged.state (representation.universe c.term.level)
        else if c.term.kind == "pi" then
          return charged.state (
            representation.pi (thunk c.term.domain) (representation.closure c.environment c.term.codomain)
          )
        else if c.term.kind == "sigma" then
          return charged.state (
            representation.sigma (thunk c.term.domain) (representation.closure c.environment c.term.codomain)
          )
        else if c.term.kind == "sum-type" then
          return charged.state (representation.sumType (thunk c.term.left) (thunk c.term.right))
        else if c.term.kind == "unit-type" then
          return charged.state representation.unitType
        else if c.term.kind == "empty-type" then
          return charged.state representation.emptyType
        else if c.term.kind == "unit" then
          return charged.state representation.unit
        else if c.term.kind == "pair" then
          return charged.state (representation.pair (thunk c.term.first) (thunk c.term.second))
        else if c.term.kind == "left-injection" then
          return charged.state (representation.leftInjection (thunk c.term.value))
        else if c.term.kind == "right-injection" then
          return charged.state (representation.rightInjection (thunk c.term.value))
        else if c.term.kind == "identity-type" then
          return charged.state (
            representation.identityType (thunk c.term.carrier) (thunk c.term.left) (thunk c.term.right)
          )
        else if c.term.kind == "refl" then
          return charged.state (representation.refl (thunk c.term.value))
        else if c.term.kind == "first-projection" then
          push {
            kind = "first-projection-subject";
            depth = c.depth + 1;
          } c.term.pair
        else if c.term.kind == "second-projection" then
          push {
            kind = "second-projection-subject";
            depth = c.depth + 1;
          } c.term.pair
        else if c.term.kind == "sum-elimination" then
          push {
            kind = "sum-elimination-scrutinee";
            inherit (c) environment;
            inherit (c.term) motive leftBranch rightBranch;
            depth = c.depth + 1;
          } c.term.scrutinee
        else if c.term.kind == "unit-elimination" then
          push {
            kind = "unit-elimination-scrutinee";
            inherit (c) environment;
            inherit (c.term) motive case;
            depth = c.depth + 1;
          } c.term.scrutinee
        else if c.term.kind == "empty-elimination" then
          push {
            kind = "empty-elimination-scrutinee";
            inherit (c) environment;
            inherit (c.term) motive;
            depth = c.depth + 1;
          } c.term.scrutinee
        else if c.term.kind == "identity-elimination" then
          push {
            kind = "identity-elimination-scrutinee";
            inherit (c) environment;
            inherit (c.term) motive reflBranch;
            depth = c.depth + 1;
          } c.term.scrutinee
        else
          fail charged.state result.codes.unknownTerm { kind = c.term.kind or null; };

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
          fail state result.codes.staleSemanticGeneration { }
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
        trace = builtins.foldl' (xs: x: [ x ] ++ xs) [ ] final.trace;
      }
    else if final.status == "done" && final.terminal != null then
      result.machineSuccess final.terminal final
    else
      (result.internalBug result.codes.impossibleMachineState { inherit (final) status; })
      // {
        inherit (final) nodes fuel;
        trace = [ ];
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
