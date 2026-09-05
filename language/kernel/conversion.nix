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
  observer,
}:
let
  sem = evaluation.representation;
  inherit (logismos) computation relation;
  liftRelation =
    leftProgram: rightProgram: selected:
    computation.bind (computation.product leftProgram rightProgram) (
      values: selected (builtins.elemAt values 0) (builtins.elemAt values 1)
    );
  inherit (budget) initial;
  inherit (budget) merge;
  semanticFailure =
    depth: checked:
    result.internal "conversion" depth (
      if checked.reason == "stale" then result.codes.staleGeneration else result.codes.malformedSemantic
    );
  mismatch =
    depth: result.failure "conversion" depth result.codes.mismatch [ ] "convertible" "distinct";
  # conversion enters once while recursive relations own their comparison charges
  chargeComparison =
    costName: limits: depth: protected:
    budget.protect "conversion" limits costName depth protected;
  semanticFailureProgram = depth: checked: computation.fail (semanticFailure depth checked);
  mismatchProgram = depth: computation.fail (mismatch depth);
  typedNeutralRelationUnobserved =
    limits: ctx: left: right:
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
    chargeComparison "compareNeutral" limits ctx.depth (
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
            malformed = result.internal "conversion" ctx.depth result.codes.malformedSemantic;
            mismatch = failure;
          }
        )
    );
  typedNeutralRelation =
    limits: ctx: left: right:
    observer.emit { operation = "kernel.conversion.neutral"; } (
      typedNeutralRelationUnobserved limits ctx left right
    );
  typeHandlers = {
    "empty-type" =
      _limits: _ctx: _left: _right:
      computation.pure null;
    "identity-type" =
      limits: ctx: left: right:
      relation.dependentProduct {
        leftFirst = semantic.demand "conversion" limits ctx.depth left.carrier;
        rightFirst = semantic.demand "conversion" limits ctx.depth right.carrier;
        firstRelation = compareTypeProgram limits ctx;
        secondRelation =
          leftCarrier: _rightCarrier:
          relation.pointwise (
            leftCell: rightCell:
            liftRelation (semantic.demand "conversion" limits ctx.depth leftCell) (semantic.demand "conversion"
              limits
              ctx.depth
              rightCell
            ) (compareValueProgram limits ctx leftCarrier)
          ) (mismatch ctx.depth) [ left.left left.right ] [ right.left right.right ];
      };
    neutral =
      limits: ctx: left: right:
      typedNeutralRelation limits ctx left right;
    pi = dependentTypeRelation;
    sigma = dependentTypeRelation;
    "sum-type" =
      limits: ctx: left: right:
      relation.product
        (
          leftCell: rightCell:
          liftRelation (semantic.demand "conversion" limits ctx.depth leftCell) (semantic.demand "conversion"
            limits
            ctx.depth
            rightCell
          ) (compareTypeProgram limits ctx)
        )
        (
          leftCell: rightCell:
          liftRelation (semantic.demand "conversion" limits ctx.depth leftCell) (semantic.demand "conversion"
            limits
            ctx.depth
            rightCell
          ) (compareTypeProgram limits ctx)
        )
        [ left.left left.right ]
        [ right.left right.right ];
    "unit-type" =
      _limits: _ctx: _left: _right:
      computation.pure null;
    universe =
      _limits: ctx: left: right:
      if core.levels.equal left.level right.level then
        computation.pure null
      else
        mismatchProgram ctx.depth;
  };
  valueHandlers = {
    "empty-type" =
      limits: ctx: _type: left: right:
      if left.kind == "neutral" && right.kind == "neutral" then
        typedNeutralRelation limits ctx left right
      else
        mismatchProgram ctx.depth;
    "identity-type" =
      limits: ctx: type: left: right:
      if left.kind == "refl" && right.kind == "refl" then
        computation.bind (semantic.demand "conversion" limits ctx.depth type.carrier) (
          carrier:
          liftRelation (semantic.demand "conversion" limits ctx.depth left.value) (semantic.demand
            "conversion"
            limits
            ctx.depth
            right.value
          ) (compareValueProgram limits ctx carrier)
        )
      else if left.kind == "neutral" && right.kind == "neutral" then
        typedNeutralRelation limits ctx left right
      else
        mismatchProgram ctx.depth;
    pi =
      limits: ctx: type: left: right:
      relation.extensional {
        witness = computation.bind (semantic.demand "conversion" limits ctx.depth type.domain) (
          domain:
          computation.map (extended: {
            inherit extended;
            argument = sem.valueCell (sem.neutral ctx.depth);
          }) (context.extendComputed "conversion" limits ctx domain)
        );
        apply = value: retained: semantic.apply "conversion" limits (ctx.depth + 1) value retained.argument;
        codomain =
          retained: semantic.apply "conversion" limits (ctx.depth + 1) type.codomain retained.argument;
        relation = retained: codomain: compareValueProgram limits retained.extended codomain;
      } left right;
    sigma =
      limits: ctx: type: left: right:
      relation.dependentProduct {
        leftFirst = semantic.project "conversion" limits ctx.depth "first" left;
        rightFirst = semantic.project "conversion" limits ctx.depth "first" right;
        firstRelation =
          leftFirst: rightFirst:
          computation.bind (semantic.demand "conversion" limits ctx.depth type.domain) (
            domain: compareValueProgram limits ctx domain leftFirst rightFirst
          );
        secondRelation =
          leftFirst: _rightFirst:
          computation.bind
            (semantic.apply "conversion" limits ctx.depth type.codomain (sem.valueCell leftFirst))
            (
              codomain:
              liftRelation (semantic.project "conversion" limits ctx.depth "second" left) (semantic.project
                "conversion"
                limits
                ctx.depth
                "second"
                right
              ) (compareValueProgram limits ctx codomain)
            );
      };
    "sum-type" =
      limits: ctx: type: left: right:
      if left.kind == "neutral" && right.kind == "neutral" then
        typedNeutralRelation limits ctx left right
      else
        relation.sum {
          classify =
            value:
            if value.kind == "left-injection" then
              "left"
            else if value.kind == "right-injection" then
              "right"
            else
              "mismatch";
          leftRelation =
            leftCell: rightCell:
            computation.bind (semantic.demand "conversion" limits ctx.depth type.left) (
              side:
              liftRelation (semantic.demand "conversion" limits ctx.depth leftCell) (semantic.demand "conversion"
                limits
                ctx.depth
                rightCell
              ) (compareValueProgram limits ctx side)
            );
          rightRelation =
            leftCell: rightCell:
            computation.bind (semantic.demand "conversion" limits ctx.depth type.right) (
              side:
              liftRelation (semantic.demand "conversion" limits ctx.depth leftCell) (semantic.demand "conversion"
                limits
                ctx.depth
                rightCell
              ) (compareValueProgram limits ctx side)
            );
          mismatch = mismatch ctx.depth;
        } left right;
    "unit-type" =
      _limits: _ctx: _type: _left: _right:
      computation.pure null;
    universe =
      limits: ctx: _type: left: right:
      compareTypeProgram limits ctx left right;
  };
  handlerKeys = {
    type = builtins.attrNames typeHandlers;
    value = builtins.attrNames valueHandlers;
    producerType = evaluation.representation.schema.conversionRoles.typeKinds;
    producerValue = evaluation.representation.schema.conversionRoles.valueKinds;
  };
  handlersClosed =
    handlerKeys.type == handlerKeys.producerType && handlerKeys.value == handlerKeys.producerValue;
  dependentTypeRelation =
    limits: ctx: left: right:
    relation.dependentProduct {
      leftFirst = semantic.demand "conversion" limits ctx.depth left.domain;
      rightFirst = semantic.demand "conversion" limits ctx.depth right.domain;
      firstRelation = compareTypeProgram limits ctx;
      secondRelation =
        leftDomain: _rightDomain:
        computation.bind (context.extendComputed "conversion" limits ctx leftDomain) (
          extended:
          let
            fresh = sem.valueCell (sem.neutral ctx.depth);
          in
          liftRelation (semantic.apply "conversion" limits (ctx.depth + 1) left.codomain fresh) (
            semantic.apply
            "conversion"
            limits
            (ctx.depth + 1)
            right.codomain
            fresh
          ) (compareTypeProgram limits extended)
        );
    };
  compareTypeProgram =
    limits: ctx: left: right:
    observer.emit { operation = "kernel.conversion.type"; } (
      chargeComparison "compareType" limits ctx.depth (
        _paid:
        let
          lc = representation.semanticShape left;
          rc = representation.semanticShape right;
        in
        if !lc.ok then
          semanticFailureProgram ctx.depth lc
        else if !rc.ok then
          semanticFailureProgram ctx.depth rc
        else if !handlersClosed then
          computation.fail (result.internal "conversion" ctx.depth result.codes.impossibleState)
        else if
          !(builtins.hasAttr left.kind typeHandlers) || !(builtins.hasAttr right.kind typeHandlers)
        then
          computation.fail (result.internal "conversion" ctx.depth result.codes.expectedType)
        else if left.kind != right.kind then
          mismatchProgram ctx.depth
        else
          typeHandlers.${left.kind} limits ctx left right
      )
    );
  compareValueProgram =
    limits: ctx: type: left: right:
    observer.emit { operation = "kernel.conversion.term"; } (
      chargeComparison "compareTerm" limits ctx.depth (
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
        else if !handlersClosed then
          computation.fail (result.internal "conversion" ctx.depth result.codes.impossibleState)
        else if !(builtins.hasAttr type.kind valueHandlers) then
          computation.fail (result.internal "conversion" ctx.depth result.codes.expectedType)
        else
          valueHandlers.${type.kind} limits ctx type left right
      )
    );
  convertTypeProgram =
    limits: ctx: left: right:
    budget.protect "conversion" limits "enterTypeConversion" ctx.depth (
      _entered: compareTypeProgram limits ctx left right
    );
  convertTermProgram =
    limits: ctx: type: left: right:
    budget.protect "conversion" limits "enterTermConversion" ctx.depth (
      _entered: compareValueProgram limits ctx type left right
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
      materializeProgram state (convertTypeProgram limits contextValue left right);
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
      materializeProgram state (convertTermProgram limits contextValue type left right);
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
      resolved = observer.emit { operation = "kernel.conversion.oracle"; } (merge limits);
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
    convertTypeProgram
    convertTermProgram
    compareTypesAt
    compareTermsAt
    handlerKeys
    ;
}
