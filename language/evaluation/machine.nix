{
  core,
  representation,
  result,
  budget,
  logismos,
}:
let
  lists = import ../internal/lists.nix;
  inherit (lists) reverse;
  transitionAlgebra = logismos.transition;
  stack = import ../logismos/stack.nix;
  mergeLimits = result.resolveLimits;
  termHandlers = {
    annotation = "annotation";
    application = "application";
    "empty-elimination" = "empty-elimination";
    "empty-type" = "empty-type";
    "first-projection" = "first-projection";
    "identity-elimination" = "identity-elimination";
    "identity-type" = "identity-type";
    lambda = "lambda";
    "left-injection" = "left-injection";
    pair = "pair";
    pi = "pi";
    refl = "refl";
    "right-injection" = "right-injection";
    "second-projection" = "second-projection";
    sigma = "sigma";
    "sum-elimination" = "sum-elimination";
    "sum-type" = "sum-type";
    unit = "unit";
    "unit-elimination" = "unit-elimination";
    "unit-type" = "unit-type";
    universe = "universe";
    variable = "variable";
  };
  eliminatorHandlers = {
    "empty-elimination" = "empty-elimination-scrutinee";
    "first-projection" = "first-projection-subject";
    "identity-elimination" = "identity-elimination-scrutinee";
    "second-projection" = "second-projection-subject";
    "sum-elimination" = "sum-elimination-scrutinee";
    "unit-elimination" = "unit-elimination-scrutinee";
  };
  frameHandlers = {
    "apply-operator" = "application";
    "empty-elimination-scrutinee" = "empty-elimination";
    "first-projection-subject" = "first-projection";
    "identity-elimination-scrutinee" = "identity-elimination";
    "second-projection-subject" = "second-projection";
    "sum-elimination-scrutinee" = "sum-elimination";
    "unit-elimination-scrutinee" = "unit-elimination";
  };
  authority = {
    termKinds = builtins.attrNames termHandlers;
    eliminatorKinds = builtins.attrNames eliminatorHandlers;
  };
  charge =
    limits: state: depth:
    let
      charged = budget.semanticNode {
        inherit limits depth;
        inherit (state) usage;
      };
    in
    if !charged.ok then
      charged
    else
      {
        ok = true;
        state = result.emit (state // { inherit (charged) usage; }) {
          kind = "charge";
          dimension = "node";
          consumed = charged.usage.nodes;
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
    else if stack.isEmpty state.frames then
      state
      // {
        status = "done";
        control = null;
        terminal = value;
      }
    else
      let
        frame = stack.top state.frames;
        rest = stack.pop state.frames;
        resumed = state // {
          frames = rest;
        };
        frameKind = if builtins.hasAttr frame.kind frameHandlers then frameHandlers.${frame.kind} else null;
      in
      # frame environments are checked before current wrappers can capture them
      if frame ? environment && !representation.generationMatches frame.environment then
        fail resumed result.codes.staleSemanticGeneration { }
      else if frameKind == "application" then
        applyValue resumed value frame.argument frame.depth
      else if frameKind == "first-projection" then
        if value.kind == "pair" then
          demandCell resumed value.first frame.depth
        else if value.kind == "neutral" then
          return resumed (representation.extendNeutral value { kind = "first-projection"; })
        else
          fail resumed result.codes.invalidSemanticValue { kind = value.kind or null; }
      else if frameKind == "second-projection" then
        if value.kind == "pair" then
          demandCell resumed value.second frame.depth
        else if value.kind == "neutral" then
          return resumed (representation.extendNeutral value { kind = "second-projection"; })
        else
          fail resumed result.codes.invalidSemanticValue { kind = value.kind or null; }
      else if frameKind == "sum-elimination" then
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
      else if frameKind == "unit-elimination" then
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
      else if frameKind == "empty-elimination" then
        if value.kind == "neutral" then
          return resumed (
            representation.extendNeutral value {
              kind = "empty-elimination";
              motive = representation.closure frame.environment frame.motive;
            }
          )
        else
          fail resumed result.codes.invalidSemanticValue { kind = value.kind or null; }
      else if frameKind == "identity-elimination" then
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
    let
      chargedStep = budget.machineStep {
        inherit limits;
        inherit (state) usage;
      };
    in
    if !chargedStep.ok then
      state
      // {
        status = "done";
        control = null;
        inherit (chargedStep) failure;
      }
    else
      let
        fueled = state // {
          inherit (chargedStep) usage;
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
          termKind = if builtins.hasAttr c.term.kind termHandlers then termHandlers.${c.term.kind} else null;
          thunk = child: representation.thunkCell c.environment child;
          push =
            frame: term:
            charged.state
            // {
              frames = stack.push frame charged.state.frames;
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
        else if termKind == "variable" then
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
        else if termKind == "lambda" then
          return (result.emit charged.state {
            kind = "closure";
            level = c.environment.nextLevel;
          }) (representation.closure c.environment c.term.body)
        else if termKind == "application" then
          push {
            kind = "apply-operator";
            argument = thunk c.term.argument;
            depth = c.depth + 1;
          } c.term.function
        else if termKind == "annotation" then
          eval (result.emit charged.state { kind = "annotation-erased"; }) c.environment c.term.subject (
            c.depth + 1
          )
        else if termKind == "universe" then
          return charged.state (representation.universe c.term.level)
        else if termKind == "pi" then
          return charged.state (
            representation.pi (thunk c.term.domain) (representation.closure c.environment c.term.codomain)
          )
        else if termKind == "sigma" then
          return charged.state (
            representation.sigma (thunk c.term.domain) (representation.closure c.environment c.term.codomain)
          )
        else if termKind == "sum-type" then
          return charged.state (representation.sumType (thunk c.term.left) (thunk c.term.right))
        else if termKind == "unit-type" then
          return charged.state representation.unitType
        else if termKind == "empty-type" then
          return charged.state representation.emptyType
        else if termKind == "unit" then
          return charged.state representation.unit
        else if termKind == "pair" then
          return charged.state (representation.pair (thunk c.term.first) (thunk c.term.second))
        else if termKind == "left-injection" then
          return charged.state (representation.leftInjection (thunk c.term.value))
        else if termKind == "right-injection" then
          return charged.state (representation.rightInjection (thunk c.term.value))
        else if termKind == "identity-type" then
          return charged.state (
            representation.identityType (thunk c.term.carrier) (thunk c.term.left) (thunk c.term.right)
          )
        else if termKind == "refl" then
          return charged.state (representation.refl (thunk c.term.value))
        else if termKind == "first-projection" then
          push {
            kind = eliminatorHandlers.${termKind};
            depth = c.depth + 1;
          } c.term.pair
        else if termKind == "second-projection" then
          push {
            kind = eliminatorHandlers.${termKind};
            depth = c.depth + 1;
          } c.term.pair
        else if termKind == "sum-elimination" then
          push {
            kind = eliminatorHandlers.${termKind};
            inherit (c) environment;
            inherit (c.term) motive leftBranch rightBranch;
            depth = c.depth + 1;
          } c.term.scrutinee
        else if termKind == "unit-elimination" then
          push {
            kind = eliminatorHandlers.${termKind};
            inherit (c) environment;
            inherit (c.term) motive case;
            depth = c.depth + 1;
          } c.term.scrutinee
        else if termKind == "empty-elimination" then
          push {
            kind = eliminatorHandlers.${termKind};
            inherit (c) environment;
            inherit (c.term) motive;
            depth = c.depth + 1;
          } c.term.scrutinee
        else if termKind == "identity-elimination" then
          push {
            kind = eliminatorHandlers.${termKind};
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
    frames = stack.empty;
    usage = budget.initial;
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
      boundedResult = mergeLimits limits;
      bounded = boundedResult.value or result.limits;
      initial =
        if
          state.status == "running"
          && state.control.kind == "eval"
          && !representation.generationMatches state.control.environment
        then
          fail state result.codes.staleSemanticGeneration { }
        else
          state;
      final = transitionAlgebra.run {
        inherit initial;
        terminal = current: current.status != "running";
        step = transition bounded;
      };
    in
    if !boundedResult.ok then
      boundedResult.failure
    else if final.failure != null then
      final.failure
      // {
        nodes = final.usage.nodes;
        fuel = final.usage.fuel;
        trace = reverse final.trace;
      }
    else if final.status == "done" && final.terminal != null then
      result.machineSuccess final.terminal final
    else
      (result.internalBug result.codes.impossibleMachineState { inherit (final) status; })
      // {
        nodes = final.usage.nodes;
        fuel = final.usage.fuel;
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
  inherit
    runState
    initialState
    transition
    authority
    ;
}
