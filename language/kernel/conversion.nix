{
  core,
  evaluation,
  representation,
  result,
  context,
  readback,
  semantic,
  budget,
  neutralTransition,
  logismos,
}:
let
  sem = evaluation.representation;
  inherit (logismos) computation;
  inherit (budget) initial;
  inherit (budget) merge;
  semanticFailure =
    depth: checked:
    result.internal "conversion" depth (
      if checked.reason == "stale" then result.codes.staleGeneration else result.codes.malformedSemantic
    );
  mismatch =
    depth: result.failure "conversion" depth result.codes.mismatch [ ] "convertible" "distinct";
  chargeProgram =
    limits: depth:
    computation.bind (budget.charge "conversion" limits "conversion" depth) (
      _conversion: budget.charge "conversion" limits "comparison" depth
    );
  semanticFailureProgram = depth: checked: computation.fail (semanticFailure depth checked);
  mismatchProgram = depth: computation.fail (mismatch depth);
  neutralCompareProgram =
    limits: ctx: type: left: right:
    let
      leftChecked = representation.neutralShape left;
      rightChecked = representation.neutralShape right;
      failure = mismatch ctx.depth;
      found = if leftChecked.ok then context.lookup ctx left.head.level else { ok = false; };
      observe =
        descriptor: _observer:
        if descriptor.item.kind == "application" then
          computation.bind (neutralTransition.applicationDomain descriptor) (
            domain:
            computation.bind (neutralTransition.applicationArguments descriptor) (
              arguments:
              computation.map (_same: null) (compareValueProgram limits ctx domain arguments.left arguments.right)
            )
          )
        else if
          descriptor.item.kind == "first-projection" || descriptor.item.kind == "second-projection"
        then
          computation.pure null
        else if descriptor.item.kind == "sum-elimination" then
          computation.bind (neutralTransition.sumMotive descriptor) (
            motive:
            computation.bind (compareTypeProgram limits motive.context motive.left motive.right) (
              _motives:
              computation.bind (neutralTransition.sumBranch descriptor "left") (
                leftBranch:
                computation.bind
                  (compareValueProgram limits leftBranch.context leftBranch.target leftBranch.left leftBranch.right)
                  (
                    _left:
                    computation.bind (neutralTransition.sumBranch descriptor "right") (
                      rightBranch:
                      computation.map (_right: null) (
                        compareValueProgram limits rightBranch.context rightBranch.target rightBranch.left rightBranch.right
                      )
                    )
                  )
              )
            )
          )
        else if descriptor.item.kind == "unit-elimination" then
          computation.bind (neutralTransition.unitMotive descriptor) (
            motive:
            computation.bind (compareTypeProgram limits motive.context motive.left motive.right) (
              _motives:
              computation.bind (neutralTransition.unitCases descriptor) (
                cases:
                computation.map (_cases: null) (compareValueProgram limits ctx cases.target cases.left cases.right)
              )
            )
          )
        else if descriptor.item.kind == "empty-elimination" then
          computation.bind (neutralTransition.emptyMotive descriptor) (
            motive:
            computation.map (_motives: null) (compareTypeProgram limits motive.context motive.left motive.right)
          )
        else
          computation.bind (neutralTransition.identityMotive descriptor) (
            motive:
            computation.bind (compareTypeProgram limits motive.context motive.left motive.right) (
              _motives:
              computation.bind (neutralTransition.identityBranches descriptor motive.carrier) (
                branches:
                computation.map (_branches: null) (
                  compareValueProgram limits branches.context branches.target branches.left branches.right
                )
              )
            )
          );
    in
    computation.bind (chargeProgram limits ctx.depth) (
      _paid:
      if !leftChecked.ok then
        semanticFailureProgram ctx.depth leftChecked
      else if !rightChecked.ok then
        semanticFailureProgram ctx.depth rightChecked
      else if left.head.level != right.head.level then
        computation.fail failure
      else if !found.ok then
        computation.fail found
      else
        computation.map (_replayed: null) (
          neutralTransition.replay {
            judgment = "conversion";
            inherit limits ctx observe;
            initial = {
              inherit (found) type;
              value = sem.neutral left.head.level;
              observer = null;
            };
            peerValue = sem.neutral right.head.level;
            inherit (left) spine spineCount;
            peerSpine = right.spine;
            peerSpineCount = right.spineCount;
            budgetName = "comparison";
            malformed = result.internal "conversion" ctx.depth result.codes.malformedSemantic;
            mismatch = failure;
          }
        )
    );
  compareTypeProgram =
    limits: ctx: left: right:
    computation.bind (chargeProgram limits ctx.depth) (
      _paid:
      let
        lc = representation.semanticShape left;
        rc = representation.semanticShape right;
        dependent = computation.bind (semantic.demand "conversion" limits ctx.depth left.domain) (
          leftDomain:
          computation.bind (semantic.demand "conversion" limits ctx.depth right.domain) (
            rightDomain:
            computation.bind (compareTypeProgram limits ctx leftDomain rightDomain) (
              _domains:
              computation.bind (context.extendComputed "conversion" limits ctx leftDomain) (
                extended:
                let
                  fresh = sem.valueCell (sem.neutral ctx.depth);
                in
                computation.bind (semantic.apply "conversion" limits (ctx.depth + 1) left.codomain fresh) (
                  leftCodomain:
                  computation.bind (semantic.apply "conversion" limits (ctx.depth + 1) right.codomain fresh) (
                    rightCodomain: compareTypeProgram limits extended leftCodomain rightCodomain
                  )
                )
              )
            )
          )
        );
      in
      if !lc.ok then
        semanticFailureProgram ctx.depth lc
      else if !rc.ok then
        semanticFailureProgram ctx.depth rc
      else if left.kind != right.kind then
        mismatchProgram ctx.depth
      else if left.kind == "universe" then
        if core.levels.equal left.level right.level then
          computation.pure null
        else
          mismatchProgram ctx.depth
      else if left.kind == "unit-type" || left.kind == "empty-type" then
        computation.pure null
      else if left.kind == "pi" || left.kind == "sigma" then
        dependent
      else if left.kind == "sum-type" then
        computation.bind (semantic.demand "conversion" limits ctx.depth left.left) (
          leftLeft:
          computation.bind (semantic.demand "conversion" limits ctx.depth right.left) (
            rightLeft:
            computation.bind (compareTypeProgram limits ctx leftLeft rightLeft) (
              _left:
              computation.bind (semantic.demand "conversion" limits ctx.depth left.right) (
                leftRight:
                computation.bind (semantic.demand "conversion" limits ctx.depth right.right) (
                  rightRight: compareTypeProgram limits ctx leftRight rightRight
                )
              )
            )
          )
        )
      else if left.kind == "identity-type" then
        computation.bind (semantic.demand "conversion" limits ctx.depth left.carrier) (
          leftCarrier:
          computation.bind (semantic.demand "conversion" limits ctx.depth right.carrier) (
            rightCarrier:
            computation.bind (compareTypeProgram limits ctx leftCarrier rightCarrier) (
              _carrier:
              computation.bind (semantic.demand "conversion" limits ctx.depth left.left) (
                leftSource:
                computation.bind (semantic.demand "conversion" limits ctx.depth right.left) (
                  rightSource:
                  computation.bind (compareValueProgram limits ctx leftCarrier leftSource rightSource) (
                    _source:
                    computation.bind (semantic.demand "conversion" limits ctx.depth left.right) (
                      leftTarget:
                      computation.bind (semantic.demand "conversion" limits ctx.depth right.right) (
                        rightTarget: compareValueProgram limits ctx leftCarrier leftTarget rightTarget
                      )
                    )
                  )
                )
              )
            )
          )
        )
      else if left.kind == "neutral" then
        neutralCompareProgram limits ctx (sem.universe core.levels.zero) left right
      else
        computation.fail (result.internal "conversion" ctx.depth result.codes.expectedType)
    );
  compareValueProgram =
    limits: ctx: type: left: right:
    computation.bind (chargeProgram limits ctx.depth) (
      _paid:
      let
        tc = representation.semanticShape type;
        lc = representation.semanticShape left;
        rc = representation.semanticShape right;
      in
      if !tc.ok then
        semanticFailureProgram ctx.depth tc
      else if !lc.ok then
        semanticFailureProgram ctx.depth lc
      else if !rc.ok then
        semanticFailureProgram ctx.depth rc
      else if type.kind == "universe" then
        compareTypeProgram limits ctx left right
      else if type.kind == "unit-type" then
        computation.pure null
      else if type.kind == "pi" then
        computation.bind (semantic.demand "conversion" limits ctx.depth type.domain) (
          domain:
          computation.bind (context.extendComputed "conversion" limits ctx domain) (
            extended:
            let
              fresh = sem.valueCell (sem.neutral ctx.depth);
            in
            computation.bind (semantic.apply "conversion" limits (ctx.depth + 1) left fresh) (
              leftBody:
              computation.bind (semantic.apply "conversion" limits (ctx.depth + 1) right fresh) (
                rightBody:
                computation.bind (semantic.apply "conversion" limits (ctx.depth + 1) type.codomain fresh) (
                  codomain: compareValueProgram limits extended codomain leftBody rightBody
                )
              )
            )
          )
        )
      else if type.kind == "sigma" then
        computation.bind (semantic.project "conversion" limits ctx.depth "first" left) (
          leftFirst:
          computation.bind (semantic.project "conversion" limits ctx.depth "first" right) (
            rightFirst:
            computation.bind (semantic.demand "conversion" limits ctx.depth type.domain) (
              domain:
              computation.bind (compareValueProgram limits ctx domain leftFirst rightFirst) (
                _first:
                computation.bind
                  (semantic.apply "conversion" limits ctx.depth type.codomain (sem.valueCell leftFirst))
                  (
                    codomain:
                    computation.bind (semantic.project "conversion" limits ctx.depth "second" left) (
                      leftSecond:
                      computation.bind (semantic.project "conversion" limits ctx.depth "second" right) (
                        rightSecond: compareValueProgram limits ctx codomain leftSecond rightSecond
                      )
                    )
                  )
              )
            )
          )
        )
      else if type.kind == "sum-type" then
        if left.kind != right.kind then
          mismatchProgram ctx.depth
        else if left.kind == "left-injection" || left.kind == "right-injection" then
          computation.bind
            (semantic.demand "conversion" limits ctx.depth
              type.${if left.kind == "left-injection" then "left" else "right"}
            )
            (
              side:
              computation.bind (semantic.demand "conversion" limits ctx.depth left.value) (
                leftValue:
                computation.bind (semantic.demand "conversion" limits ctx.depth right.value) (
                  rightValue: compareValueProgram limits ctx side leftValue rightValue
                )
              )
            )
        else if left.kind == "neutral" then
          neutralCompareProgram limits ctx type left right
        else
          mismatchProgram ctx.depth
      else if type.kind == "empty-type" then
        if left.kind == "neutral" && right.kind == "neutral" then
          neutralCompareProgram limits ctx type left right
        else
          mismatchProgram ctx.depth
      else if type.kind == "identity-type" then
        if left.kind == "refl" && right.kind == "refl" then
          computation.bind (semantic.demand "conversion" limits ctx.depth type.carrier) (
            carrier:
            computation.bind (semantic.demand "conversion" limits ctx.depth left.value) (
              leftWitness:
              computation.bind (semantic.demand "conversion" limits ctx.depth right.value) (
                rightWitness: compareValueProgram limits ctx carrier leftWitness rightWitness
              )
            )
          )
        else if left.kind == "neutral" && right.kind == "neutral" then
          neutralCompareProgram limits ctx type left right
        else
          mismatchProgram ctx.depth
      else if left.kind == "neutral" && right.kind == "neutral" then
        neutralCompareProgram limits ctx type left right
      else
        mismatchProgram ctx.depth
    );
  materializeProgram =
    state: program:
    let
      executed = semantic.runStateful {
        judgment = "conversion";
        inherit state program;
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
  finish =
    judgment: type: compared:
    if !compared.ok then
      compared
    else if judgment == "type-conversion" then
      result.typeConversion { resources = representation.resources compared.state; }
    else
      result.termConversion {
        inherit type;
        resources = representation.resources compared.state;
        observations = {
          forced = compared.state.forced or 0;
        };
      };
  compareTypesAt =
    {
      contextValue,
      left,
      right,
      state,
      limits,
    }:
    if !context.validate contextValue then
      result.internal "type-conversion" 0 result.codes.malformedContext
    else
      materializeProgram state (compareTypeProgram limits contextValue left right);
  compareTermsAt =
    {
      contextValue,
      type,
      left,
      right,
      state,
      limits,
    }:
    if !context.validate contextValue then
      result.internal "term-conversion" 0 result.codes.malformedContext
    else
      materializeProgram state (compareValueProgram limits contextValue type left right);
  convertTypes =
    {
      contextValue,
      left,
      right,
      limits ? { },
    }:
    let
      resolved = merge limits;
      bounded = resolved.value or representation.limits;
    in
    if !resolved.ok then
      resolved
    else
      finish "type-conversion" null (compareTypesAt {
        inherit contextValue left right;
        limits = bounded;
        state = initial // {
          limits = bounded;
        };
      });
  convertTerms =
    {
      contextValue,
      type,
      left,
      right,
      limits ? { },
    }:
    let
      resolved = merge limits;
      bounded = resolved.value or representation.limits;
    in
    if !resolved.ok then
      resolved
    else
      finish "term-conversion" type (compareTermsAt {
        inherit
          contextValue
          type
          left
          right
          ;
        limits = bounded;
        state = initial // {
          limits = bounded;
        };
      });
  oracle =
    {
      contextValue,
      type,
      left,
      right,
      limits ? { },
    }:
    let
      resolved = merge limits;
      bounded = resolved.value;
      ql = readback.quoteAt {
        inherit contextValue type;
        value = left;
        limits = bounded;
        state = initial;
      };
      qr =
        if ql.ok then
          readback.quoteAt {
            inherit contextValue type;
            value = right;
            limits = bounded;
            inherit (ql) state;
          }
        else
          ql;
      admit = value: core.operations.admitted (core.representation.envelope contextValue.depth value [ ]);
      leftCanonical = if qr.ok then admit ql.value else qr;
      rightCanonical = if leftCanonical.ok then admit qr.value else leftCanonical;
    in
    if !resolved.ok then
      resolved
    else if !ql.ok then
      ql
    else if !qr.ok then
      qr
    else if !leftCanonical.ok || !rightCanonical.ok then
      result.internal "conversion-oracle" contextValue.depth result.codes.impossibleState
    else if core.operations.structurallyEqual leftCanonical.value rightCanonical.value then
      result.oracle {
        left = leftCanonical.value;
        right = rightCanonical.value;
        resources = representation.resources qr.state;
      }
    else
      mismatch contextValue.depth;
in
{
  inherit
    convertTypes
    convertTerms
    oracle
    compareTypeProgram
    compareValueProgram
    compareTypesAt
    compareTermsAt
    ;
}
