{
  core,
  evaluation,
  representation,
  result,
  context,
  readback,
  conversion,
}:
let
  r = core.representation;
  semantic = evaluation.representation;
  fail =
    judgment: ctx: expected: received:
    result.failure judgment ctx.depth result.codes.expectedType [ ] expected received;
  semanticFailure =
    judgment: ctx: checked:
    result.internal judgment ctx.depth (
      if checked.reason == "stale" then result.codes.staleGeneration else result.codes.malformedSemantic
    );
  evalTerm =
    ctx: term:
    let
      evaluated = evaluation.direct.runRoot {
        root = term;
        inherit (ctx) environment;
      };
      checked =
        if evaluated.ok then
          representation.semanticShape evaluated.value
        else
          {
            ok = false;
            reason = "malformed";
          };
    in
    if !evaluated.ok then
      result.internal "evaluation" ctx.depth result.codes.evaluation
    else if !checked.ok then
      semanticFailure "evaluation" ctx checked
    else
      {
        ok = true;
        inherit (evaluated) value;
      };
  charge =
    judgment: ctx: state:
    # every judgment transition charges the operation-owned state before inspecting syntax
    if state.checking >= state.limits.checking then
      result.resource judgment ctx.depth "checking" state.limits.checking state.checking
    else if ctx.depth > state.limits.depth then
      result.resource judgment ctx.depth "depth" state.limits.depth ctx.depth
    else
      {
        ok = true;
        state = state // {
          checking = state.checking + 1;
          depth = if ctx.depth > state.depth then ctx.depth else state.depth;
        };
      };
  formAt =
    ctx: term: state:
    let
      inferred = inferAt ctx term state;
    in
    if !inferred.ok then
      inferred
    else if inferred.type.kind != "universe" then
      fail "formation" ctx "universe" inferred.type.kind
    else
      let
        normalized = core.levels.normalize inferred.type.level;
      in
      if !normalized.ok then
        result.internal "formation" ctx.depth result.codes.expectedType
      else
        {
          ok = true;
          type = inferred.value;
          level = normalized.value;
          inherit (inferred) state;
        };
  inferAt =
    ctx: term: state:
    let
      paid = charge "inference" ctx state;
    in
    if !paid.ok then
      paid
    else if term.kind == "variable" then
      let
        found = context.lookup ctx term.level;
        value = evalTerm ctx term;
      in
      if !found.ok then
        found
      else if !value.ok then
        value
      else
        {
          ok = true;
          inherit (found) type;
          inherit (value) value;
          inherit (paid) state;
        }
    else if term.kind == "annotation" then
      let
        formed = formAt ctx term.annotation paid.state;
      in
      if !formed.ok then
        formed
      else
        let
          checked = checkAt ctx term.subject formed.type formed.state;
        in
        if !checked.ok then
          checked
        else
          let
            value = evalTerm ctx term;
          in
          if !value.ok then
            value
          else
            {
              ok = true;
              inherit (formed) type;
              inherit (value) value;
              inherit (checked) state;
            }
    else if term.kind == "application" then
      let
        function = inferAt ctx term.function paid.state;
      in
      if !function.ok then
        function
      else if function.type.kind != "pi" then
        fail "inference" ctx "pi" function.type.kind
      else
        let
          domain = readback.demand paid.state.limits function.state ctx.depth function.type.domain;
        in
        if !domain.ok then
          domain
        else
          let
            argument = checkAt ctx term.argument domain.value domain.state;
          in
          if !argument.ok then
            argument
          else
            let
              argumentValue = evalTerm ctx term.argument;
            in
            if !argumentValue.ok then
              argumentValue
            else
              let
                codomain = readback.apply paid.state.limits argument.state ctx.depth function.type.codomain (
                  semantic.valueCell argumentValue.value
                );
              in
              if !codomain.ok then
                codomain
              else
                let
                  value = evalTerm ctx term;
                in
                if !value.ok then
                  value
                else
                  {
                    ok = true;
                    type = codomain.value;
                    inherit (value) value;
                    inherit (codomain) state;
                  }
    else if term.kind == "universe" then
      let
        successor = core.levels.successor term.level;
        value = evalTerm ctx term;
      in
      if !successor.ok then
        result.internal "formation" ctx.depth result.codes.expectedType
      else if !value.ok then
        value
      else
        {
          ok = true;
          type = semantic.universe successor.value;
          inherit (value) value;
          inherit (paid) state;
        }
    else if term.kind == "unit-type" || term.kind == "empty-type" then
      let
        value = evalTerm ctx term;
      in
      if !value.ok then
        value
      else
        {
          ok = true;
          type = semantic.universe core.levels.zero;
          inherit (value) value;
          inherit (paid) state;
        }
    else if term.kind == "pi" || term.kind == "sigma" then
      let
        domain = formAt ctx term.domain paid.state;
      in
      if !domain.ok then
        domain
      else
        let
          extended = readback.extendContext state.limits domain.state ctx domain.type;
        in
        if !extended.ok then
          extended
        else
          let
            codomain = formAt extended.value term.codomain extended.state;
          in
          if !codomain.ok then
            codomain
          else
            let
              maximum = core.levels.maximum domain.level codomain.level;
              value = evalTerm ctx term;
            in
            if !maximum.ok then
              result.internal "formation" ctx.depth result.codes.expectedType
            else if !value.ok then
              value
            else
              {
                ok = true;
                type = semantic.universe maximum.value;
                inherit (value) value;
                inherit (codomain) state;
              }
    else if term.kind == "sum-type" then
      let
        left = formAt ctx term.left paid.state;
      in
      if !left.ok then
        left
      else
        let
          right = formAt ctx term.right left.state;
        in
        if !right.ok then
          right
        else
          let
            maximum = core.levels.maximum left.level right.level;
            value = evalTerm ctx term;
          in
          if !maximum.ok then
            result.internal "formation" ctx.depth result.codes.expectedType
          else if !value.ok then
            value
          else
            {
              ok = true;
              type = semantic.universe maximum.value;
              inherit (value) value;
              inherit (right) state;
            }
    else if term.kind == "identity-type" then
      let
        carrier = formAt ctx term.carrier paid.state;
      in
      if !carrier.ok then
        carrier
      else
        let
          left = checkAt ctx term.left carrier.type carrier.state;
        in
        if !left.ok then
          left
        else
          let
            right = checkAt ctx term.right carrier.type left.state;
          in
          if !right.ok then
            right
          else
            let
              value = evalTerm ctx term;
            in
            if !value.ok then
              value
            else
              {
                ok = true;
                type = semantic.universe carrier.level;
                inherit (value) value;
                inherit (right) state;
              }
    else if term.kind == "sum-elimination" then
      let
        subject = inferAt ctx term.scrutinee paid.state;
      in
      if !subject.ok then
        subject
      else if subject.type.kind != "sum-type" then
        fail "inference" ctx "sum-type" subject.type.kind
      else
        let
          motiveContext = readback.extendContext state.limits subject.state ctx subject.type;
        in
        if !motiveContext.ok then
          motiveContext
        else
          let
            motiveFormation = formAt motiveContext.value term.motive motiveContext.state;
          in
          if !motiveFormation.ok then
            motiveFormation
          else
            let
              motive = semantic.closure ctx.environment term.motive;
              leftType = readback.demand paid.state.limits motiveFormation.state ctx.depth subject.type.left;
            in
            if !leftType.ok then
              leftType
            else
              let
                leftContext = readback.extendContext state.limits leftType.state ctx leftType.value;
              in
              if !leftContext.ok then
                leftContext
              else
                let
                  leftNeutral = semantic.neutral ctx.depth;
                  leftExpected = readback.apply paid.state.limits leftContext.state (ctx.depth + 1) motive (
                    semantic.valueCell (semantic.leftInjection (semantic.valueCell leftNeutral))
                  );
                in
                if !leftExpected.ok then
                  leftExpected
                else
                  let
                    leftChecked = checkAt leftContext.value term.leftBranch leftExpected.value leftExpected.state;
                  in
                  if !leftChecked.ok then
                    leftChecked
                  else
                    let
                      rightType = readback.demand paid.state.limits leftChecked.state ctx.depth subject.type.right;
                    in
                    if !rightType.ok then
                      rightType
                    else
                      let
                        rightContext = readback.extendContext state.limits rightType.state ctx rightType.value;
                      in
                      if !rightContext.ok then
                        rightContext
                      else
                        let
                          rightNeutral = semantic.neutral ctx.depth;
                          rightExpected = readback.apply paid.state.limits rightContext.state (ctx.depth + 1) motive (
                            semantic.valueCell (semantic.rightInjection (semantic.valueCell rightNeutral))
                          );
                        in
                        if !rightExpected.ok then
                          rightExpected
                        else
                          let
                            rightChecked = checkAt rightContext.value term.rightBranch rightExpected.value rightExpected.state;
                          in
                          if !rightChecked.ok then
                            rightChecked
                          else
                            let
                              target = readback.apply paid.state.limits rightChecked.state ctx.depth motive (
                                semantic.valueCell subject.value
                              );
                            in
                            if !target.ok then
                              target
                            else
                              let
                                value = evalTerm ctx term;
                              in
                              if !value.ok then
                                value
                              else
                                {
                                  ok = true;
                                  type = target.value;
                                  inherit (value) value;
                                  inherit (target) state;
                                }
    else if term.kind == "unit-elimination" then
      let
        subject = inferAt ctx term.scrutinee paid.state;
      in
      if !subject.ok then
        subject
      else if subject.type.kind != "unit-type" then
        fail "inference" ctx "unit-type" subject.type.kind
      else
        let
          motiveContext = readback.extendContext state.limits subject.state ctx semantic.unitType;
        in
        if !motiveContext.ok then
          motiveContext
        else
          let
            motiveFormation = formAt motiveContext.value term.motive motiveContext.state;
          in
          if !motiveFormation.ok then
            motiveFormation
          else
            let
              motive = semantic.closure ctx.environment term.motive;
              caseType = readback.apply paid.state.limits motiveFormation.state ctx.depth motive (
                semantic.valueCell semantic.unit
              );
            in
            if !caseType.ok then
              caseType
            else
              let
                caseChecked = checkAt ctx term.case caseType.value caseType.state;
              in
              if !caseChecked.ok then
                caseChecked
              else
                let
                  target = readback.apply paid.state.limits caseChecked.state ctx.depth motive (
                    semantic.valueCell subject.value
                  );
                in
                if !target.ok then
                  target
                else
                  let
                    value = evalTerm ctx term;
                  in
                  if !value.ok then
                    value
                  else
                    {
                      ok = true;
                      type = target.value;
                      inherit (value) value;
                      inherit (target) state;
                    }
    else if term.kind == "empty-elimination" then
      let
        subject = inferAt ctx term.scrutinee paid.state;
      in
      if !subject.ok then
        subject
      else if subject.type.kind != "empty-type" then
        fail "inference" ctx "empty-type" subject.type.kind
      else
        let
          motiveContext = readback.extendContext state.limits subject.state ctx semantic.emptyType;
        in
        if !motiveContext.ok then
          motiveContext
        else
          let
            motiveFormation = formAt motiveContext.value term.motive motiveContext.state;
          in
          if !motiveFormation.ok then
            motiveFormation
          else
            let
              motive = semantic.closure ctx.environment term.motive;
              target = readback.apply paid.state.limits motiveFormation.state ctx.depth motive (
                semantic.valueCell subject.value
              );
            in
            if !target.ok then
              target
            else
              let
                value = evalTerm ctx term;
              in
              if !value.ok then
                value
              else
                {
                  ok = true;
                  type = target.value;
                  inherit (value) value;
                  inherit (target) state;
                }
    else if term.kind == "identity-elimination" then
      let
        subject = inferAt ctx term.scrutinee paid.state;
      in
      if !subject.ok then
        subject
      else if subject.type.kind != "identity-type" then
        fail "inference" ctx "identity-type" subject.type.kind
      else
        let
          carrier = readback.demand paid.state.limits subject.state ctx.depth subject.type.carrier;
        in
        if !carrier.ok then
          carrier
        else
          let
            sourceContext = readback.extendContext state.limits carrier.state ctx carrier.value;
          in
          if !sourceContext.ok then
            sourceContext
          else
            let
              targetContext =
                readback.extendContext state.limits sourceContext.state sourceContext.value
                  carrier.value;
            in
            if !targetContext.ok then
              targetContext
            else
              let
                sourceNeutral = semantic.neutral ctx.depth;
                targetNeutral = semantic.neutral (ctx.depth + 1);
                evidenceType =
                  semantic.identityType (semantic.valueCell carrier.value) (semantic.valueCell sourceNeutral)
                    (semantic.valueCell targetNeutral);
                motiveContext =
                  readback.extendContext state.limits targetContext.state targetContext.value
                    evidenceType;
              in
              if !motiveContext.ok then
                motiveContext
              else
                let
                  motiveFormation = formAt motiveContext.value term.motive motiveContext.state;
                in
                if !motiveFormation.ok then
                  motiveFormation
                else
                  let
                    witnessContext = readback.extendContext state.limits motiveFormation.state ctx carrier.value;
                  in
                  if !witnessContext.ok then
                    witnessContext
                  else
                    let
                      witness = semantic.neutral ctx.depth;
                      motiveEnvironment1 = semantic.extendEnvironment ctx.environment (semantic.valueCell witness);
                      motiveEnvironment2 =
                        if motiveEnvironment1.ok then
                          semantic.extendEnvironment motiveEnvironment1.value (semantic.valueCell witness)
                        else
                          motiveEnvironment1;
                      motiveEnvironment3 =
                        if motiveEnvironment2.ok then
                          semantic.extendEnvironment motiveEnvironment2.value (
                            semantic.valueCell (semantic.refl (semantic.valueCell witness))
                          )
                        else
                          motiveEnvironment2;
                      reflExpected =
                        if motiveEnvironment3.ok then
                          evaluation.direct.runRoot {
                            root = term.motive;
                            environment = motiveEnvironment3.value;
                          }
                        else
                          motiveEnvironment3;
                    in
                    if !reflExpected.ok then
                      result.internal "inference" ctx.depth result.codes.evaluation
                    else
                      let
                        reflChecked = checkAt witnessContext.value term.reflBranch reflExpected.value witnessContext.state;
                      in
                      if !reflChecked.ok then
                        reflChecked
                      else
                        let
                          left = readback.demand paid.state.limits reflChecked.state ctx.depth subject.type.left;
                        in
                        if !left.ok then
                          left
                        else
                          let
                            right = readback.demand paid.state.limits left.state ctx.depth subject.type.right;
                          in
                          if !right.ok then
                            right
                          else
                            let
                              env1 = semantic.extendEnvironment ctx.environment (semantic.valueCell left.value);
                              env2 =
                                if env1.ok then semantic.extendEnvironment env1.value (semantic.valueCell right.value) else env1;
                              env3 =
                                if env2.ok then semantic.extendEnvironment env2.value (semantic.valueCell subject.value) else env2;
                              target =
                                if env3.ok then
                                  evaluation.direct.runRoot {
                                    root = term.motive;
                                    environment = env3.value;
                                  }
                                else
                                  env3;
                            in
                            if !target.ok then
                              result.internal "inference" ctx.depth result.codes.evaluation
                            else
                              let
                                value = evalTerm ctx term;
                              in
                              if !value.ok then
                                value
                              else
                                {
                                  ok = true;
                                  type = target.value;
                                  inherit (value) value;
                                  inherit (right) state;
                                }
    else if term.kind == "first-projection" || term.kind == "second-projection" then
      let
        pair = inferAt ctx term.pair paid.state;
      in
      if !pair.ok then
        pair
      else if pair.type.kind != "sigma" then
        fail "inference" ctx "sigma" pair.type.kind
      else
        let
          domain = readback.demand paid.state.limits pair.state ctx.depth pair.type.domain;
        in
        if !domain.ok then
          domain
        else
          let
            selected =
              if term.kind == "first-projection" then
                {
                  ok = true;
                  inherit (domain) value;
                  inherit (domain) state;
                }
              else
                let
                  first = readback.project paid.state.limits domain.state ctx.depth "first" pair.value;
                in
                if !first.ok then
                  first
                else
                  readback.apply paid.state.limits first.state ctx.depth pair.type.codomain (
                    semantic.valueCell first.value
                  );
            value = evalTerm ctx term;
          in
          if !selected.ok then
            selected
          else if !value.ok then
            value
          else
            {
              ok = true;
              type = selected.value;
              inherit (value) value;
              inherit (selected) state;
            }
    else
      fail "inference" ctx "synthesizing constructor" term.kind;
  checkAt =
    ctx: term: expected: state:
    let
      paid = charge "checking" ctx state;
      checkedExpected = representation.semanticShape expected;
    in
    if !paid.ok then
      paid
    else if !checkedExpected.ok then
      semanticFailure "checking" ctx checkedExpected
    else if term.kind == "lambda" && expected.kind == "pi" then
      let
        domain = readback.demand paid.state.limits paid.state ctx.depth expected.domain;
      in
      if !domain.ok then
        domain
      else
        let
          extended = readback.extendContext state.limits domain.state ctx domain.value;
        in
        if !extended.ok then
          extended
        else
          let
            codomain = readback.apply paid.state.limits extended.state (ctx.depth + 1) expected.codomain (
              semantic.valueCell (semantic.neutral ctx.depth)
            );
          in
          if !codomain.ok then codomain else checkAt extended.value term.body codomain.value codomain.state
    else if term.kind == "pair" && expected.kind == "sigma" then
      let
        domain = readback.demand paid.state.limits paid.state ctx.depth expected.domain;
      in
      if !domain.ok then
        domain
      else
        let
          first = checkAt ctx term.first domain.value domain.state;
        in
        if !first.ok then
          first
        else
          let
            firstValue = evalTerm ctx term.first;
          in
          if !firstValue.ok then
            firstValue
          else
            let
              codomain = readback.apply paid.state.limits first.state ctx.depth expected.codomain (
                semantic.valueCell firstValue.value
              );
            in
            if !codomain.ok then codomain else checkAt ctx term.second codomain.value codomain.state
    else if
      (term.kind == "left-injection" || term.kind == "right-injection") && expected.kind == "sum-type"
    then
      let
        cell = if term.kind == "left-injection" then expected.left else expected.right;
        side = readback.demand paid.state.limits paid.state ctx.depth cell;
      in
      if !side.ok then side else checkAt ctx term.value side.value side.state
    else if term.kind == "unit" && expected.kind == "unit-type" then
      {
        ok = true;
        inherit (paid) state;
      }
    else if term.kind == "refl" && expected.kind == "identity-type" then
      let
        carrier = readback.demand paid.state.limits paid.state ctx.depth expected.carrier;
      in
      if !carrier.ok then
        carrier
      else
        let
          witness = checkAt ctx term.value carrier.value carrier.state;
        in
        if !witness.ok then
          witness
        else
          let
            witnessValue = evalTerm ctx term.value;
          in
          if !witnessValue.ok then
            witnessValue
          else
            let
              left = readback.demand paid.state.limits witness.state ctx.depth expected.left;
            in
            if !left.ok then
              left
            else
              let
                right = readback.demand paid.state.limits left.state ctx.depth expected.right;
              in
              if !right.ok then
                right
              else
                let
                  a = conversion.compareTermsAt {
                    contextValue = ctx;
                    type = carrier.value;
                    left = witnessValue.value;
                    right = left.value;
                    limits = paid.state.limits;
                    inherit (right) state;
                  };
                in
                if !a.ok then
                  a
                else
                  let
                    b = conversion.compareTermsAt {
                      contextValue = ctx;
                      type = carrier.value;
                      left = witnessValue.value;
                      right = right.value;
                      limits = paid.state.limits;
                      inherit (a) state;
                    };
                  in
                  if !b.ok then
                    b
                  else
                    {
                      ok = true;
                      inherit (b) state;
                    }
    else
      let
        inferred = inferAt ctx term paid.state;
      in
      if !inferred.ok then
        inferred
      else
        let
          same = conversion.compareTypesAt {
            contextValue = ctx;
            left = inferred.type;
            right = expected;
            limits = paid.state.limits;
            inherit (inferred) state;
          };
        in
        if !same.ok then
          same
        else
          {
            ok = true;
            inherit (same) state;
          };
  admitRoot =
    ctx: envelope:
    if !context.validate ctx then
      result.internal "judgment" 0 result.codes.malformedContext
    else
      let
        admitted = core.operations.admitted envelope;
      in
      if !admitted.ok || admitted.value.scope != ctx.depth then
        result.failure "judgment" ctx.depth result.codes.outOfScope [ ] "matching scope" "invalid envelope"
      else
        {
          ok = true;
          term = admitted.value.root;
        };
  checkContext =
    {
      entries,
      limits ? { },
    }:
    let
      bounded = representation.limits // limits;
      outer = builtins.tryEval (builtins.isList entries);
      states =
        if !outer.success || !outer.value then
          [ ]
        else
          builtins.genericClosure {
            startSet = [
              {
                key = 0;
                status = "running";
                remaining = entries;
                value = context.empty;
                kernelState = readback.initial // {
                  limits = bounded;
                };
                consumed = 0;
                failure = null;
              }
            ];
            operator =
              state:
              if state.status != "running" then
                [ ]
              else
                let
                  empty = builtins.tryEval (state.remaining == [ ]);
                  nextKey = state.key + 1;
                in
                if !empty.success then
                  [
                    (
                      state
                      // {
                        key = nextKey;
                        status = "done";
                        failure = result.internal "context" state.value.depth result.codes.malformedContext;
                      }
                    )
                  ]
                else if empty.value then
                  [
                    (
                      state
                      // {
                        key = nextKey;
                        status = "done";
                      }
                    )
                  ]
                else if state.consumed >= bounded.context then
                  [
                    (
                      state
                      // {
                        key = nextKey;
                        status = "done";
                        failure = result.resource "context" state.value.depth "context" bounded.context state.consumed;
                      }
                    )
                  ]
                else
                  let
                    observed = builtins.tryEval (
                      let
                        entry = builtins.head state.remaining;
                        tail = builtins.tail state.remaining;
                      in
                      builtins.seq entry (builtins.seq tail { inherit entry tail; })
                    );
                  in
                  if !observed.success then
                    [
                      (
                        state
                        // {
                          key = nextKey;
                          status = "done";
                          failure = result.internal "context" state.value.depth result.codes.malformedContext;
                        }
                      )
                    ]
                  else
                    let
                      admitted = admitRoot state.value observed.value.entry;
                    in
                    if !admitted.ok then
                      [
                        (
                          state
                          // {
                            key = nextKey;
                            status = "done";
                            failure = admitted;
                          }
                        )
                      ]
                    else
                      let
                        formed = formAt state.value admitted.term (state.kernelState // { context = state.consumed + 1; });
                      in
                      if !formed.ok then
                        [
                          (
                            state
                            // {
                              key = nextKey;
                              status = "done";
                              failure = formed;
                            }
                          )
                        ]
                      else
                        let
                          extended = context.extend state.value formed.type;
                        in
                        if !extended.ok then
                          [
                            (
                              state
                              // {
                                key = nextKey;
                                status = "done";
                                failure = extended;
                              }
                            )
                          ]
                        else
                          [
                            (
                              state
                              // {
                                key = nextKey;
                                remaining = observed.value.tail;
                                inherit (extended) value;
                                kernelState = formed.state;
                                consumed = state.consumed + 1;
                              }
                            )
                          ];
          };
      final = if states == [ ] then null else builtins.elemAt states (builtins.length states - 1);
    in
    if !outer.success || !outer.value then
      result.internal "context" 0 result.codes.malformedContext
    else if final.failure != null then
      final.failure
    else
      result.checkedContext {
        context = final.value;
        resources = representation.resources (
          final.kernelState
          // {
            context = final.consumed;
            depth = final.value.depth;
          }
        );
      };
  form =
    {
      contextValue,
      envelope,
      limits ? { },
    }:
    let
      admitted = admitRoot contextValue envelope;
    in
    if !admitted.ok then
      admitted
    else
      let
        bounded = representation.limits // limits;
        formed = formAt contextValue admitted.term (readback.initial // { limits = bounded; });
      in
      if !formed.ok then
        formed
      else
        result.formation {
          inherit (formed) level;
          inherit (formed) type;
          resources = representation.resources formed.state;
        };
  infer =
    {
      contextValue,
      envelope,
      limits ? { },
    }:
    let
      admitted = admitRoot contextValue envelope;
    in
    if !admitted.ok then
      admitted
    else
      let
        bounded = representation.limits // limits;
        inferred = inferAt contextValue admitted.term (readback.initial // { limits = bounded; });
      in
      if !inferred.ok then
        inferred
      else
        result.inference {
          inherit (inferred) type;
          inherit (inferred) value;
          resources = representation.resources inferred.state;
        };
  check =
    {
      contextValue,
      envelope,
      expected,
      limits ? { },
    }:
    let
      admitted = admitRoot contextValue envelope;
    in
    if !admitted.ok then
      admitted
    else
      let
        bounded = representation.limits // limits;
        checked = checkAt contextValue admitted.term expected (readback.initial // { limits = bounded; });
      in
      if !checked.ok then
        checked
      else
        let
          value = evalTerm contextValue admitted.term;
        in
        if !value.ok then
          value
        else
          result.checking {
            type = expected;
            inherit (value) value;
            resources = representation.resources checked.state;
          };
in
{
  inherit
    checkContext
    form
    infer
    check
    ;
}
