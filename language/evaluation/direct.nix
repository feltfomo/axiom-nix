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
  inherit (logismos) computation;
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
    "empty-elimination" = "empty-elimination";
    "first-projection" = "first-projection";
    "identity-elimination" = "identity-elimination";
    "second-projection" = "second-projection";
    "sum-elimination" = "sum-elimination";
    "unit-elimination" = "unit-elimination";
  };
  authority = {
    termKinds = builtins.attrNames termHandlers;
    eliminatorKinds = builtins.attrNames eliminatorHandlers;
  };
  runRoot =
    {
      root,
      environment,
      limits ? { },
    }:
    let
      boundedResult = mergeLimits limits;
      bounded = boundedResult.value or result.limits;
      emit = event: computation.modify (state: result.emit state event);
      charge =
        depth:
        computation.bind computation.get (
          state:
          let
            charged = budget.semanticNode {
              limits = bounded;
              inherit depth;
              inherit (state) usage;
            };
          in
          if !charged.ok then
            computation.fail charged.failure
          else
            computation.bind (computation.modify (current: current // { inherit (charged) usage; })) (
              _unit:
              emit {
                kind = "charge";
                dimension = "node";
                consumed = charged.usage.nodes;
                inherit depth;
              }
            )
        );
      bad =
        value:
        computation.fail (
          result.internalBug result.codes.invalidSemanticValue {
            kind = value.kind or null;
          }
        );
      demand =
        cell: depth:
        if !representation.generationMatches cell then
          computation.fail (result.internalBug result.codes.staleSemanticGeneration { })
        else if cell.kind == "value" then
          if representation.generationMatches cell.value then
            computation.pure cell.value
          else
            computation.fail (result.internalBug result.codes.staleSemanticGeneration { })
        else if cell.kind == "thunk" then
          if representation.generationMatches cell.environment then
            evaluate cell.environment depth cell.term
          else
            computation.fail (result.internalBug result.codes.staleSemanticGeneration { })
        else
          computation.fail (
            result.internalBug result.codes.invalidEnvironmentCell {
              kind = cell.kind or null;
            }
          );
      apply =
        function: argument: depth:
        if !representation.generationMatches function then
          computation.fail (result.internalBug result.codes.staleSemanticGeneration { })
        else if function.kind == "closure" then
          let
            extended = representation.extendEnvironment function.environment argument;
          in
          if extended.ok then
            computation.bind (emit {
              kind = "closure-application";
              level = function.environment.nextLevel;
            }) (_unit: evaluate extended.value depth function.body)
          else
            computation.fail (result.internalBug result.codes.staleSemanticGeneration { })
        else if function.kind == "neutral" then
          computation.bind
            (emit {
              kind = "neutral-application";
              level = function.head.level;
              spineLength = function.spineCount + 1;
            })
            (
              _unit:
              computation.pure (
                representation.extendNeutral function {
                  kind = "application";
                  inherit argument;
                }
              )
            )
        else
          bad function;
      eliminate =
        environment: depth: term: subject:
        if !(builtins.hasAttr term.kind eliminatorHandlers) then
          bad subject
        else
          let
            eliminationKind = eliminatorHandlers.${term.kind};
          in
          if eliminationKind == "first-projection" then
            if subject.kind == "pair" then
              demand subject.first depth
            else if subject.kind == "neutral" then
              computation.pure (representation.extendNeutral subject { kind = "first-projection"; })
            else
              bad subject
          else if eliminationKind == "second-projection" then
            if subject.kind == "pair" then
              demand subject.second depth
            else if subject.kind == "neutral" then
              computation.pure (representation.extendNeutral subject { kind = "second-projection"; })
            else
              bad subject
          else if eliminationKind == "sum-elimination" then
            if subject.kind == "left-injection" || subject.kind == "right-injection" then
              apply (representation.closure environment (
                if subject.kind == "left-injection" then term.leftBranch else term.rightBranch
              )) subject.value depth
            else if subject.kind == "neutral" then
              computation.pure (
                representation.extendNeutral subject {
                  kind = "sum-elimination";
                  motive = representation.closure environment term.motive;
                  leftBranch = representation.closure environment term.leftBranch;
                  rightBranch = representation.closure environment term.rightBranch;
                }
              )
            else
              bad subject
          else if eliminationKind == "unit-elimination" then
            if subject.kind == "unit" then
              evaluate environment depth term.case
            else if subject.kind == "neutral" then
              computation.pure (
                representation.extendNeutral subject {
                  kind = "unit-elimination";
                  motive = representation.closure environment term.motive;
                  case = representation.thunkCell environment term.case;
                }
              )
            else
              bad subject
          else if eliminationKind == "empty-elimination" then
            if subject.kind == "neutral" then
              computation.pure (
                representation.extendNeutral subject {
                  kind = "empty-elimination";
                  motive = representation.closure environment term.motive;
                }
              )
            else
              bad subject
          else if eliminationKind == "identity-elimination" then
            if subject.kind == "refl" then
              apply (representation.closure environment term.reflBranch) subject.value depth
            else if subject.kind == "neutral" then
              computation.pure (
                representation.extendNeutral subject {
                  kind = "identity-elimination";
                  motive = representation.closure environment term.motive;
                  reflBranch = representation.closure environment term.reflBranch;
                }
              )
            else
              bad subject
          else
            bad subject;
      evaluate =
        env: depth: term:
        computation.bind (charge depth) (
          _unit:
          let
            thunk = child: representation.thunkCell env child;
            termKind = if builtins.hasAttr term.kind termHandlers then termHandlers.${term.kind} else null;
          in
          if termKind == "variable" then
            let
              found = representation.lookupEnvironment env term.level;
              lookup = emit {
                kind = "lookup";
                inherit (term) level;
              };
            in
            computation.bind lookup (
              _lookup:
              if !found.ok then
                computation.fail (
                  result.internalBug (
                    if found.reason == "generation" then
                      result.codes.staleSemanticGeneration
                    else
                      result.codes.missingEnvironmentLevel
                  ) found
                )
              else
                computation.bind (
                  if found.cell.kind == "thunk" then
                    emit {
                      kind = "force";
                      inherit (term) level;
                    }
                  else
                    computation.pure null
                ) (_forced: demand found.cell depth)
            )
          else if termKind == "lambda" then
            computation.bind (emit {
              kind = "closure";
              level = env.nextLevel;
            }) (_closed: computation.pure (representation.closure env term.body))
          else if termKind == "application" then
            computation.bind (evaluate env (depth + 1) term.function) (
              operator: apply operator (thunk term.argument) (depth + 1)
            )
          else if termKind == "annotation" then
            computation.bind (emit { kind = "annotation-erased"; }) (
              _erased: evaluate env (depth + 1) term.subject
            )
          else if termKind == "universe" then
            computation.pure (representation.universe term.level)
          else if termKind == "pi" then
            computation.pure (representation.pi (thunk term.domain) (representation.closure env term.codomain))
          else if termKind == "sigma" then
            computation.pure (
              representation.sigma (thunk term.domain) (representation.closure env term.codomain)
            )
          else if termKind == "sum-type" then
            computation.pure (representation.sumType (thunk term.left) (thunk term.right))
          else if termKind == "unit-type" then
            computation.pure representation.unitType
          else if termKind == "empty-type" then
            computation.pure representation.emptyType
          else if termKind == "unit" then
            computation.pure representation.unit
          else if termKind == "pair" then
            computation.pure (representation.pair (thunk term.first) (thunk term.second))
          else if termKind == "left-injection" then
            computation.pure (representation.leftInjection (thunk term.value))
          else if termKind == "right-injection" then
            computation.pure (representation.rightInjection (thunk term.value))
          else if termKind == "identity-type" then
            computation.pure (
              representation.identityType (thunk term.carrier) (thunk term.left) (thunk term.right)
            )
          else if termKind == "refl" then
            computation.pure (representation.refl (thunk term.value))
          else if
            builtins.elem termKind [
              "first-projection"
              "second-projection"
              "sum-elimination"
              "unit-elimination"
              "empty-elimination"
              "identity-elimination"
            ]
          then
            computation.bind (evaluate env (depth + 1) (term.pair or term.scrutinee)) (
              subject: eliminate env (depth + 1) term subject
            )
          else
            computation.fail (result.internalBug result.codes.unknownTerm { kind = term.kind or null; })
        );
      initial = {
        usage = budget.initial;
        trace = [ ];
      };
      program =
        if representation.generationMatches environment then
          evaluate environment 0 root
        else
          computation.fail (result.internalBug result.codes.staleSemanticGeneration { });
      executed = computation.run {
        computation = program;
        reader = null;
        state = initial;
      };
    in
    if !boundedResult.ok then
      boundedResult.failure
    else if executed.kind == "success" then
      result.success executed.value executed.state
    else
      executed.failure
      // {
        nodes = executed.state.usage.nodes;
        trace = reverse executed.state.trace;
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
  inherit runRoot authority;
}
