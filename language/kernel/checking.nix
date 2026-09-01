{
  core,
  evaluation,
  representation,
  result,
  context,
  semantic,
  budget,
  conversion,
  logismos,
}:
let
  sem = evaluation.representation;
  inherit (logismos) computation;
  fail =
    judgment: ctx: expected: received:
    result.failure judgment ctx.depth result.codes.expectedType [ ] expected received;
  semanticFailure =
    judgment: ctx: checked:
    result.internal judgment ctx.depth (
      if checked.reason == "stale" then result.codes.staleGeneration else result.codes.malformedSemantic
    );
  checkingFailure =
    judgment: ctx: expected: received:
    computation.fail (fail judgment ctx expected received);
  semanticFailureProgram =
    judgment: ctx: checked:
    computation.fail (semanticFailure judgment ctx checked);
  chargeProgram =
    judgment: limits: ctx:
    budget.charge judgment limits "checking" ctx.depth;
  evalTermProgram = ctx: term: semantic.evalRoot "evaluation" ctx.environment term;
  formProgram =
    limits: ctx: term:
    computation.bind (inferProgram limits ctx term) (
      inferred:
      if inferred.type.kind != "universe" then
        checkingFailure "formation" ctx "universe" inferred.type.kind
      else
        let
          normalized = core.levels.normalize inferred.type.level;
        in
        if !normalized.ok then
          computation.fail (result.internal "formation" ctx.depth result.codes.expectedType)
        else
          computation.pure {
            type = inferred.value;
            level = normalized.value;
          }
    );
  inferProgram =
    limits: ctx: term:
    computation.bind (chargeProgram "inference" limits ctx) (
      _paid:
      if term.kind == "variable" then
        let
          found = context.lookup ctx term.level;
        in
        if !found.ok then
          computation.fail found
        else
          computation.map (value: {
            inherit (found) type;
            inherit value;
          }) (evalTermProgram ctx term)
      else if term.kind == "annotation" then
        computation.bind (formProgram limits ctx term.annotation) (
          formed:
          computation.bind (checkProgram limits ctx term.subject formed.type) (
            _checked:
            computation.map (value: {
              inherit (formed) type;
              inherit value;
            }) (evalTermProgram ctx term)
          )
        )
      else if term.kind == "application" then
        computation.bind (inferProgram limits ctx term.function) (
          function:
          if function.type.kind != "pi" then
            checkingFailure "inference" ctx "pi" function.type.kind
          else
            computation.bind (semantic.demand "checking" limits ctx.depth function.type.domain) (
              domain:
              computation.bind (checkProgram limits ctx term.argument domain) (
                _argument:
                computation.bind (evalTermProgram ctx term.argument) (
                  argumentValue:
                  computation.bind
                    (semantic.apply "checking" limits ctx.depth function.type.codomain (sem.valueCell argumentValue))
                    (
                      codomain:
                      computation.map (value: {
                        type = codomain;
                        inherit value;
                      }) (evalTermProgram ctx term)
                    )
                )
              )
            )
        )
      else if term.kind == "universe" then
        let
          successor = core.levels.successor term.level;
        in
        if !successor.ok then
          computation.fail (result.internal "formation" ctx.depth result.codes.expectedType)
        else
          computation.map (value: {
            type = sem.universe successor.value;
            inherit value;
          }) (evalTermProgram ctx term)
      else if term.kind == "unit-type" || term.kind == "empty-type" then
        computation.map (value: {
          type = sem.universe core.levels.zero;
          inherit value;
        }) (evalTermProgram ctx term)
      else if term.kind == "pi" || term.kind == "sigma" then
        computation.bind (formProgram limits ctx term.domain) (
          domain:
          computation.bind (context.extendComputed "context" limits ctx domain.type) (
            extended:
            computation.bind (formProgram limits extended term.codomain) (
              codomain:
              let
                maximum = core.levels.maximum domain.level codomain.level;
              in
              if !maximum.ok then
                computation.fail (result.internal "formation" ctx.depth result.codes.expectedType)
              else
                computation.map (value: {
                  type = sem.universe maximum.value;
                  inherit value;
                }) (evalTermProgram ctx term)
            )
          )
        )
      else if term.kind == "sum-type" then
        computation.bind (formProgram limits ctx term.left) (
          left:
          computation.bind (formProgram limits ctx term.right) (
            right:
            let
              maximum = core.levels.maximum left.level right.level;
            in
            if !maximum.ok then
              computation.fail (result.internal "formation" ctx.depth result.codes.expectedType)
            else
              computation.map (value: {
                type = sem.universe maximum.value;
                inherit value;
              }) (evalTermProgram ctx term)
          )
        )
      else if term.kind == "identity-type" then
        computation.bind (formProgram limits ctx term.carrier) (
          carrier:
          computation.bind (checkProgram limits ctx term.left carrier.type) (
            _left:
            computation.bind (checkProgram limits ctx term.right carrier.type) (
              _right:
              computation.map (value: {
                type = sem.universe carrier.level;
                inherit value;
              }) (evalTermProgram ctx term)
            )
          )
        )
      else if term.kind == "sum-elimination" then
        computation.bind (inferProgram limits ctx term.scrutinee) (
          subject:
          if subject.type.kind != "sum-type" then
            checkingFailure "inference" ctx "sum-type" subject.type.kind
          else
            computation.bind (context.extendComputed "context" limits ctx subject.type) (
              motiveContext:
              computation.bind (formProgram limits motiveContext term.motive) (
                _motiveFormation:
                let
                  motive = sem.closure ctx.environment term.motive;
                in
                computation.bind (semantic.demand "checking" limits ctx.depth subject.type.left) (
                  leftType:
                  computation.bind (context.extendComputed "context" limits ctx leftType) (
                    leftContext:
                    let
                      leftNeutral = sem.neutral ctx.depth;
                    in
                    computation.bind
                      (semantic.apply "checking" limits (ctx.depth + 1) motive (
                        sem.valueCell (sem.leftInjection (sem.valueCell leftNeutral))
                      ))
                      (
                        leftExpected:
                        computation.bind (checkProgram limits leftContext term.leftBranch leftExpected) (
                          _left:
                          computation.bind (semantic.demand "checking" limits ctx.depth subject.type.right) (
                            rightType:
                            computation.bind (context.extendComputed "context" limits ctx rightType) (
                              rightContext:
                              let
                                rightNeutral = sem.neutral ctx.depth;
                              in
                              computation.bind
                                (semantic.apply "checking" limits (ctx.depth + 1) motive (
                                  sem.valueCell (sem.rightInjection (sem.valueCell rightNeutral))
                                ))
                                (
                                  rightExpected:
                                  computation.bind (checkProgram limits rightContext term.rightBranch rightExpected) (
                                    _right:
                                    computation.bind (semantic.apply "checking" limits ctx.depth motive (sem.valueCell subject.value)) (
                                      target:
                                      computation.map (value: {
                                        type = target;
                                        inherit value;
                                      }) (evalTermProgram ctx term)
                                    )
                                  )
                                )
                            )
                          )
                        )
                      )
                  )
                )
              )
            )
        )
      else if term.kind == "unit-elimination" then
        computation.bind (inferProgram limits ctx term.scrutinee) (
          subject:
          if subject.type.kind != "unit-type" then
            checkingFailure "inference" ctx "unit-type" subject.type.kind
          else
            computation.bind (context.extendComputed "context" limits ctx sem.unitType) (
              motiveContext:
              computation.bind (formProgram limits motiveContext term.motive) (
                _motiveFormation:
                let
                  motive = sem.closure ctx.environment term.motive;
                in
                computation.bind (semantic.apply "checking" limits ctx.depth motive (sem.valueCell sem.unit)) (
                  caseType:
                  computation.bind (checkProgram limits ctx term.case caseType) (
                    _case:
                    computation.bind (semantic.apply "checking" limits ctx.depth motive (sem.valueCell subject.value)) (
                      target:
                      computation.map (value: {
                        type = target;
                        inherit value;
                      }) (evalTermProgram ctx term)
                    )
                  )
                )
              )
            )
        )
      else if term.kind == "empty-elimination" then
        computation.bind (inferProgram limits ctx term.scrutinee) (
          subject:
          if subject.type.kind != "empty-type" then
            checkingFailure "inference" ctx "empty-type" subject.type.kind
          else
            computation.bind (context.extendComputed "context" limits ctx sem.emptyType) (
              motiveContext:
              computation.bind (formProgram limits motiveContext term.motive) (
                _motiveFormation:
                let
                  motive = sem.closure ctx.environment term.motive;
                in
                computation.bind (semantic.apply "checking" limits ctx.depth motive (sem.valueCell subject.value)) (
                  target:
                  computation.map (value: {
                    type = target;
                    inherit value;
                  }) (evalTermProgram ctx term)
                )
              )
            )
        )
      else if term.kind == "identity-elimination" then
        computation.bind (inferProgram limits ctx term.scrutinee) (
          subject:
          if subject.type.kind != "identity-type" then
            checkingFailure "inference" ctx "identity-type" subject.type.kind
          else
            computation.bind (semantic.demand "checking" limits ctx.depth subject.type.carrier) (
              carrier:
              computation.bind (context.extendComputed "context" limits ctx carrier) (
                sourceContext:
                computation.bind (context.extendComputed "context" limits sourceContext carrier) (
                  targetContext:
                  let
                    sourceNeutral = sem.neutral ctx.depth;
                    targetNeutral = sem.neutral (ctx.depth + 1);
                    evidenceType = sem.identityType (sem.valueCell carrier) (sem.valueCell sourceNeutral) (
                      sem.valueCell targetNeutral
                    );
                  in
                  computation.bind (context.extendComputed "context" limits targetContext evidenceType) (
                    motiveContext:
                    computation.bind (formProgram limits motiveContext term.motive) (
                      _motiveFormation:
                      computation.bind (context.extendComputed "context" limits ctx carrier) (
                        witnessContext:
                        let
                          witness = sem.neutral ctx.depth;
                          env1 = sem.extendEnvironment ctx.environment (sem.valueCell witness);
                          env2 = if env1.ok then sem.extendEnvironment env1.value (sem.valueCell witness) else env1;
                          env3 =
                            if env2.ok then
                              sem.extendEnvironment env2.value (sem.valueCell (sem.refl (sem.valueCell witness)))
                            else
                              env2;
                        in
                        if !env3.ok then
                          computation.fail (result.internal "inference" ctx.depth result.codes.evaluation)
                        else
                          computation.bind (semantic.evalRoot "evaluation" env3.value term.motive) (
                            reflExpected:
                            computation.bind (checkProgram limits witnessContext term.reflBranch reflExpected) (
                              _refl:
                              computation.bind (semantic.demand "checking" limits ctx.depth subject.type.left) (
                                left:
                                computation.bind (semantic.demand "checking" limits ctx.depth subject.type.right) (
                                  right:
                                  let
                                    targetEnv1 = sem.extendEnvironment ctx.environment (sem.valueCell left);
                                    targetEnv2 =
                                      if targetEnv1.ok then sem.extendEnvironment targetEnv1.value (sem.valueCell right) else targetEnv1;
                                    targetEnv3 =
                                      if targetEnv2.ok then
                                        sem.extendEnvironment targetEnv2.value (sem.valueCell subject.value)
                                      else
                                        targetEnv2;
                                  in
                                  if !targetEnv3.ok then
                                    computation.fail (result.internal "inference" ctx.depth result.codes.evaluation)
                                  else
                                    computation.bind (semantic.evalRoot "evaluation" targetEnv3.value term.motive) (
                                      target:
                                      computation.map (value: {
                                        type = target;
                                        inherit value;
                                      }) (evalTermProgram ctx term)
                                    )
                                )
                              )
                            )
                          )
                      )
                    )
                  )
                )
              )
            )
        )
      else if term.kind == "first-projection" || term.kind == "second-projection" then
        computation.bind (inferProgram limits ctx term.pair) (
          pair:
          if pair.type.kind != "sigma" then
            checkingFailure "inference" ctx "sigma" pair.type.kind
          else
            computation.bind (semantic.demand "checking" limits ctx.depth pair.type.domain) (
              domain:
              computation.bind
                (
                  if term.kind == "first-projection" then
                    computation.pure domain
                  else
                    computation.bind (semantic.project "checking" limits ctx.depth "first" pair.value) (
                      first: semantic.apply "checking" limits ctx.depth pair.type.codomain (sem.valueCell first)
                    )
                )
                (
                  selected:
                  computation.map (value: {
                    type = selected;
                    inherit value;
                  }) (evalTermProgram ctx term)
                )
            )
        )
      else
        checkingFailure "inference" ctx "synthesizing constructor" term.kind
    );
  checkProgram =
    limits: ctx: term: expected:
    computation.bind (chargeProgram "checking" limits ctx) (
      _paid:
      let
        checkedExpected = representation.semanticShape expected;
      in
      if !checkedExpected.ok then
        semanticFailureProgram "checking" ctx checkedExpected
      else if term.kind == "lambda" && expected.kind == "pi" then
        computation.bind (semantic.demand "checking" limits ctx.depth expected.domain) (
          domain:
          computation.bind (context.extendComputed "context" limits ctx domain) (
            extended:
            computation.bind (semantic.apply "checking" limits (ctx.depth + 1) expected.codomain (
              sem.valueCell (sem.neutral ctx.depth)
            )) (codomain: checkProgram limits extended term.body codomain)
          )
        )
      else if term.kind == "pair" && expected.kind == "sigma" then
        computation.bind (semantic.demand "checking" limits ctx.depth expected.domain) (
          domain:
          computation.bind (checkProgram limits ctx term.first domain) (
            _first:
            computation.bind (evalTermProgram ctx term.first) (
              firstValue:
              computation.bind (semantic.apply "checking" limits ctx.depth expected.codomain (
                sem.valueCell firstValue
              )) (codomain: checkProgram limits ctx term.second codomain)
            )
          )
        )
      else if
        (term.kind == "left-injection" || term.kind == "right-injection") && expected.kind == "sum-type"
      then
        computation.bind (semantic.demand "checking" limits ctx.depth (
          if term.kind == "left-injection" then expected.left else expected.right
        )) (side: checkProgram limits ctx term.value side)
      else if term.kind == "unit" && expected.kind == "unit-type" then
        computation.pure null
      else if term.kind == "refl" && expected.kind == "identity-type" then
        computation.bind (semantic.demand "checking" limits ctx.depth expected.carrier) (
          carrier:
          computation.bind (checkProgram limits ctx term.value carrier) (
            _witness:
            computation.bind (evalTermProgram ctx term.value) (
              witness:
              computation.bind (semantic.demand "checking" limits ctx.depth expected.left) (
                left:
                computation.bind (semantic.demand "checking" limits ctx.depth expected.right) (
                  right:
                  computation.bind (conversion.compareValueProgram limits ctx carrier witness left) (
                    _left: conversion.compareValueProgram limits ctx carrier witness right
                  )
                )
              )
            )
          )
        )
      else
        computation.bind (inferProgram limits ctx term) (
          inferred: conversion.compareTypeProgram limits ctx inferred.type expected
        )
    );
  materializeProgram =
    judgment: state: program:
    let
      executed = semantic.runStateful {
        inherit judgment state program;
      };
    in
    if executed.ok then
      {
        ok = true;
        inherit (executed) value;
        inherit (executed) state;
      }
    else
      executed.failure;
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
  checkContextProgram =
    limits: entries:
    let
      built = builtins.foldl' (
        current: envelope:
        computation.bind current (
          ctx:
          computation.bind (budget.charge "context" limits "context" ctx.depth) (
            _context:
            let
              admitted = admitRoot ctx envelope;
            in
            if !admitted.ok then
              computation.fail admitted
            else
              computation.bind (formProgram limits ctx admitted.term) (
                formed:
                let
                  extended = context.extend ctx formed.type;
                in
                if !extended.ok then computation.fail extended else computation.pure extended.value
              )
          )
        )
      ) (computation.pure context.empty) entries;
    in
    computation.bind built (
      checkedContext:
      computation.bind (computation.modify (
        state:
        state
        // {
          inherit (checkedContext) depth;
        }
      )) (_depth: computation.pure checkedContext)
    );
  checkContextComposed =
    {
      entries,
      limits ? { },
    }:
    let
      resolved = budget.merge limits;
      outer = builtins.tryEval (builtins.isList entries);
      executed =
        if resolved.ok && outer.success && outer.value then
          materializeProgram "context" budget.initial (checkContextProgram resolved.value entries)
        else
          null;
    in
    if !resolved.ok then
      resolved
    else if !outer.success || !outer.value then
      result.internal "context" 0 result.codes.malformedContext
    else if !executed.ok then
      executed
    else
      result.checkedContext {
        context = executed.value;
        resources = representation.resources executed.state;
      };
  formComposed =
    {
      contextValue,
      envelope,
      limits ? { },
    }:
    let
      admitted = admitRoot contextValue envelope;
      resolved = budget.merge limits;
      executed =
        if admitted.ok && resolved.ok then
          materializeProgram "formation" budget.initial (
            formProgram resolved.value contextValue admitted.term
          )
        else
          null;
    in
    if !admitted.ok then
      admitted
    else if !resolved.ok then
      resolved
    else if !executed.ok then
      executed
    else
      result.formation {
        inherit (executed.value) level type;
        resources = representation.resources executed.state;
      };
  inferComposed =
    {
      contextValue,
      envelope,
      limits ? { },
    }:
    let
      admitted = admitRoot contextValue envelope;
      resolved = budget.merge limits;
      executed =
        if admitted.ok && resolved.ok then
          materializeProgram "inference" budget.initial (
            inferProgram resolved.value contextValue admitted.term
          )
        else
          null;
    in
    if !admitted.ok then
      admitted
    else if !resolved.ok then
      resolved
    else if !executed.ok then
      executed
    else
      result.inference {
        inherit (executed.value) type value;
        resources = representation.resources executed.state;
      };
  checkComposed =
    {
      contextValue,
      envelope,
      expected,
      limits ? { },
    }:
    let
      admitted = admitRoot contextValue envelope;
      resolved = budget.merge limits;
      program = computation.bind (checkProgram resolved.value contextValue admitted.term expected) (
        _checked: evalTermProgram contextValue admitted.term
      );
      executed =
        if admitted.ok && resolved.ok then materializeProgram "checking" budget.initial program else null;
    in
    if !admitted.ok then
      admitted
    else if !resolved.ok then
      resolved
    else if !executed.ok then
      executed
    else
      result.checking {
        type = expected;
        inherit (executed) value;
        resources = representation.resources executed.state;
      };
in
{
  checkContext = checkContextComposed;
  form = formComposed;
  infer = inferComposed;
  check = checkComposed;
}
