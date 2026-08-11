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
      bad = state: value: {
        ok = false;
        failure = result.internalBug result.codes.invalidSemanticValue { kind = value.kind or null; };
        inherit state;
      };
      demand =
        state: cell: depth:
        if !representation.generationMatches cell then
          {
            ok = false;
            failure = result.internalBug result.codes.staleSemanticGeneration { };
            inherit state;
          }
        else if cell.kind == "value" then
          if representation.generationMatches cell.value then
            {
              ok = true;
              inherit (cell) value;
              inherit state;
            }
          else
            {
              ok = false;
              failure = result.internalBug result.codes.staleSemanticGeneration { };
              inherit state;
            }
        else if cell.kind == "thunk" then
          if representation.generationMatches cell.environment then
            evaluate state cell.environment depth cell.term
          else
            {
              ok = false;
              failure = result.internalBug result.codes.staleSemanticGeneration { };
              inherit state;
            }
        else
          {
            ok = false;
            failure = result.internalBug result.codes.invalidEnvironmentCell { kind = cell.kind or null; };
            inherit state;
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
          if extended.ok then
            evaluate (result.emit state {
              kind = "closure-application";
              level = function.environment.nextLevel;
            }) extended.value depth function.body
          else
            {
              ok = false;
              failure = result.internalBug result.codes.staleSemanticGeneration { };
              inherit state;
            }
        else if function.kind == "neutral" then
          {
            ok = true;
            value = representation.extendNeutral function {
              kind = "application";
              inherit argument;
            };
            state = result.emit state {
              kind = "neutral-application";
              level = function.head.level;
              spineLength = function.spineCount + 1;
            };
          }
        else
          bad state function;
      eliminate =
        state: environment: depth: term: subject:
        if term.kind == "first-projection" then
          if subject.kind == "pair" then
            demand state subject.first depth
          else if subject.kind == "neutral" then
            {
              ok = true;
              value = representation.extendNeutral subject { kind = "first-projection"; };
              inherit state;
            }
          else
            bad state subject
        else if term.kind == "second-projection" then
          if subject.kind == "pair" then
            demand state subject.second depth
          else if subject.kind == "neutral" then
            {
              ok = true;
              value = representation.extendNeutral subject { kind = "second-projection"; };
              inherit state;
            }
          else
            bad state subject
        else if term.kind == "sum-elimination" then
          # only the selected branch receives the injection payload
          if subject.kind == "left-injection" || subject.kind == "right-injection" then
            apply state (representation.closure environment (
              if subject.kind == "left-injection" then term.leftBranch else term.rightBranch
            )) subject.value depth
          else if subject.kind == "neutral" then
            {
              ok = true;
              value = representation.extendNeutral subject {
                kind = "sum-elimination";
                motive = representation.closure environment term.motive;
                leftBranch = representation.closure environment term.leftBranch;
                rightBranch = representation.closure environment term.rightBranch;
              };
              inherit state;
            }
          else
            bad state subject
        else if term.kind == "unit-elimination" then
          if subject.kind == "unit" then
            evaluate state environment depth term.case
          else if subject.kind == "neutral" then
            {
              ok = true;
              value = representation.extendNeutral subject {
                kind = "unit-elimination";
                motive = representation.closure environment term.motive;
                case = representation.thunkCell environment term.case;
              };
              inherit state;
            }
          else
            bad state subject
        else if term.kind == "empty-elimination" then
          if subject.kind == "neutral" then
            {
              ok = true;
              value = representation.extendNeutral subject {
                kind = "empty-elimination";
                motive = representation.closure environment term.motive;
              };
              inherit state;
            }
          else
            bad state subject
        else if term.kind == "identity-elimination" then
          # refl delivers its stored witness to the one-binder branch without demanding the motive
          if subject.kind == "refl" then
            apply state (representation.closure environment term.reflBranch) subject.value depth
          else if subject.kind == "neutral" then
            {
              ok = true;
              value = representation.extendNeutral subject {
                kind = "identity-elimination";
                motive = representation.closure environment term.motive;
                reflBranch = representation.closure environment term.reflBranch;
              };
              inherit state;
            }
          else
            bad state subject
        else
          bad state subject;
      evaluate =
        state: env: depth: term:
        let
          charged = charge bounded state depth;
          thunk = child: representation.thunkCell env child;
        in
        if !charged.ok then
          {
            ok = false;
            inherit (charged) failure;
            inherit state;
          }
        else if term.kind == "variable" then
          let
            found = representation.lookupEnvironment env term.level;
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
          else
            demand (
              if found.cell.kind == "thunk" then
                result.emit looked {
                  kind = "force";
                  inherit (term) level;
                }
              else
                looked
            ) found.cell depth
        else if term.kind == "lambda" then
          {
            ok = true;
            value = representation.closure env term.body;
            state = result.emit charged.state {
              kind = "closure";
              level = env.nextLevel;
            };
          }
        else if term.kind == "application" then
          let
            operator = evaluate charged.state env (depth + 1) term.function;
          in
          if operator.ok then
            apply operator.state operator.value (thunk term.argument) (depth + 1)
          else
            operator
        else if term.kind == "annotation" then
          evaluate (result.emit charged.state { kind = "annotation-erased"; }) env (depth + 1) term.subject
        else if term.kind == "universe" then
          {
            ok = true;
            value = representation.universe term.level;
            inherit (charged) state;
          }
        else if term.kind == "pi" then
          {
            ok = true;
            value = representation.pi (thunk term.domain) (representation.closure env term.codomain);
            inherit (charged) state;
          }
        else if term.kind == "sigma" then
          {
            ok = true;
            value = representation.sigma (thunk term.domain) (representation.closure env term.codomain);
            inherit (charged) state;
          }
        else if term.kind == "sum-type" then
          {
            ok = true;
            value = representation.sumType (thunk term.left) (thunk term.right);
            inherit (charged) state;
          }
        else if term.kind == "unit-type" then
          {
            ok = true;
            value = representation.unitType;
            inherit (charged) state;
          }
        else if term.kind == "empty-type" then
          {
            ok = true;
            value = representation.emptyType;
            inherit (charged) state;
          }
        else if term.kind == "unit" then
          {
            ok = true;
            value = representation.unit;
            inherit (charged) state;
          }
        else if term.kind == "pair" then
          {
            ok = true;
            value = representation.pair (thunk term.first) (thunk term.second);
            inherit (charged) state;
          }
        else if term.kind == "left-injection" then
          {
            ok = true;
            value = representation.leftInjection (thunk term.value);
            inherit (charged) state;
          }
        else if term.kind == "right-injection" then
          {
            ok = true;
            value = representation.rightInjection (thunk term.value);
            inherit (charged) state;
          }
        else if term.kind == "identity-type" then
          {
            ok = true;
            value = representation.identityType (thunk term.carrier) (thunk term.left) (thunk term.right);
            inherit (charged) state;
          }
        else if term.kind == "refl" then
          {
            ok = true;
            value = representation.refl (thunk term.value);
            inherit (charged) state;
          }
        else if
          builtins.elem term.kind [
            "first-projection"
            "second-projection"
            "sum-elimination"
            "unit-elimination"
            "empty-elimination"
            "identity-elimination"
          ]
        then
          let
            subject = evaluate charged.state env (depth + 1) (term.pair or term.scrutinee);
          in
          if subject.ok then eliminate subject.state env (depth + 1) term subject.value else subject
        else
          {
            ok = false;
            failure = result.internalBug result.codes.unknownTerm { kind = term.kind or null; };
            inherit (charged) state;
          };
      initial = {
        nodes = 0;
        trace = [ ];
      };
      evaluated =
        if representation.generationMatches environment then
          evaluate initial environment 0 root
        else
          {
            ok = false;
            failure = result.internalBug result.codes.staleSemanticGeneration { };
            state = initial;
          };
    in
    if evaluated.ok then
      result.success evaluated.value evaluated.state
    else
      evaluated.failure
      // {
        nodes = evaluated.state.nodes;
        trace = builtins.foldl' (xs: x: [ x ] ++ xs) [ ] evaluated.state.trace;
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
