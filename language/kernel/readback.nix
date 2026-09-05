{
  core,
  evaluation,
  representation,
  result,
  context,
  budget,
  semantic,
  neutralTransition,
  logismos,
}:
let
  r = core.representation;
  sem = evaluation.representation;
  inherit (logismos) computation;
  # canonical syntax construction is distinct from quotation and the semantic work it invokes
  emit =
    limits: depth: value:
    budget.protect "readback" limits "emitSyntaxNode" depth (_charged: computation.pure value);
  malformed =
    depth: checked:
    result.internal "readback" depth (
      if (checked.reason or "malformed") == "stale" then
        result.codes.staleGeneration
      else
        result.codes.malformedSemantic
    );
  reflect =
    limits: ctx: type: neutral:
    let
      typeShape = representation.semanticShape type;
      neutralShape = representation.neutralShape neutral;
    in
    if !typeShape.ok || !neutralShape.ok then
      computation.fail (malformed ctx.depth (if !typeShape.ok then typeShape else neutralShape))
    else if type.kind == "unit-type" then
      computation.pure sem.unit
    else if type.kind == "sigma" then
      computation.bind (semantic.demand "readback" limits ctx.depth type.domain) (
        domain:
        computation.bind (semantic.project "readback" limits ctx.depth "first" neutral) (
          first:
          computation.bind (reflect limits ctx domain first) (
            reflectedFirst:
            computation.bind (semantic.apply "readback" limits ctx.depth type.codomain (sem.valueCell first)) (
              codomain:
              computation.bind (semantic.project "readback" limits ctx.depth "second" neutral) (
                second:
                computation.map (
                  reflectedSecond: sem.pair (sem.valueCell reflectedFirst) (sem.valueCell reflectedSecond)
                ) (reflect limits ctx codomain second)
              )
            )
          )
        )
      )
    else
      computation.pure neutral;
  quoteNeutral =
    limits: ctx: value:
    budget.protect "readback" limits "quoteNeutral" ctx.depth (
      _paid:
      let
        neutral = representation.neutralShape value;
      in
      if !neutral.ok then
        computation.fail (malformed ctx.depth neutral)
      else if value.head.level < 0 || value.head.level >= ctx.depth then
        computation.fail (result.internal "readback" ctx.depth result.codes.outOfScope)
      else
        let
          found = context.lookup ctx value.head.level;
        in
        if !found.ok then
          computation.fail found
        else
          computation.bind (emit limits ctx.depth (r.variable value.head.level)) (
            head:
            computation.map (replayed: replayed.observer) (
              neutralTransition.replay {
                judgment = "readback";
                inherit limits ctx;
                initial = {
                  inherit (found) type;
                  value = sem.neutral value.head.level;
                  observer = head;
                };
                inherit (value) spine;
                inherit (value) spineCount;
                peerSpine = null;
                peerSpineCount = 0;
                peerValue = null;
                malformed = result.internal "readback" ctx.depth result.codes.malformedSemantic;
                mismatch = result.internal "readback" ctx.depth result.codes.malformedSemantic;
                observe =
                  descriptor: observer:
                  let
                    term = observer;
                  in
                  if descriptor.item.kind == "application" then
                    computation.bind (neutralTransition.applicationDomain descriptor) (
                      domain:
                      computation.bind (neutralTransition.applicationArguments descriptor) (
                        arguments:
                        computation.bind (quoteValue limits ctx domain arguments.left) (
                          argument: emit limits ctx.depth (r.application term argument)
                        )
                      )
                    )
                  else if descriptor.item.kind == "first-projection" then
                    emit limits ctx.depth (r.firstProjection term)
                  else if descriptor.item.kind == "second-projection" then
                    emit limits ctx.depth (r.secondProjection term)
                  else if descriptor.item.kind == "sum-elimination" then
                    computation.bind (neutralTransition.sumMotive descriptor) (
                      motive:
                      computation.bind (quoteTypeAt limits motive.context motive.left) (
                        motiveTerm:
                        computation.bind (neutralTransition.sumBranch descriptor "left") (
                          left:
                          computation.bind (quoteValue limits left.context left.target left.left) (
                            leftTerm:
                            computation.bind (neutralTransition.sumBranch descriptor "right") (
                              right:
                              computation.bind (quoteValue limits right.context right.target right.left) (
                                rightTerm: emit limits ctx.depth (r.sumElimination term motiveTerm leftTerm rightTerm)
                              )
                            )
                          )
                        )
                      )
                    )
                  else if descriptor.item.kind == "unit-elimination" then
                    computation.bind (neutralTransition.unitMotive descriptor) (
                      motive:
                      computation.bind (quoteTypeAt limits motive.context motive.left) (
                        motiveTerm:
                        computation.bind (neutralTransition.unitCases descriptor) (
                          case:
                          computation.bind (quoteValue limits ctx case.target case.left) (
                            caseTerm: emit limits ctx.depth (r.unitElimination term motiveTerm caseTerm)
                          )
                        )
                      )
                    )
                  else if descriptor.item.kind == "empty-elimination" then
                    computation.bind (neutralTransition.emptyMotive descriptor) (
                      motive:
                      computation.bind (quoteTypeAt limits motive.context motive.left) (
                        motiveTerm: emit limits ctx.depth (r.emptyElimination term motiveTerm)
                      )
                    )
                  else
                    computation.bind (neutralTransition.identityMotive descriptor) (
                      motive:
                      computation.bind (quoteTypeAt limits motive.context motive.left) (
                        motiveTerm:
                        computation.bind (neutralTransition.identityBranches descriptor motive.carrier) (
                          branch:
                          computation.bind (quoteValue limits branch.context branch.target branch.left) (
                            branchTerm: emit limits ctx.depth (r.identityElimination term motiveTerm branchTerm)
                          )
                        )
                      )
                    );
              }
            )
          )
    );
  quoteTypeAt =
    limits: ctx: value:
    budget.protect "readback" limits "quoteType" ctx.depth (
      _paid:
      let
        checked = representation.semanticShape value;
      in
      if !checked.ok then
        computation.fail (malformed ctx.depth checked)
      else if value.kind == "universe" then
        let
          normalized = core.levels.normalize value.level;
        in
        if !normalized.ok then
          computation.fail (result.internal "readback" ctx.depth result.codes.malformedSemantic)
        else
          # normalized levels reserve one output-node cost for every emitted level constructor
          computation.bind (budget.chargeNamedAmount "readback" limits "emitSyntaxNode" ctx.depth
            normalized.outputConsumed
          ) (_level: emit limits ctx.depth (r.universe normalized.value))
      else if value.kind == "unit-type" then
        emit limits ctx.depth r.unitType
      else if value.kind == "empty-type" then
        emit limits ctx.depth r.emptyType
      else if value.kind == "sum-type" then
        computation.bind (semantic.demand "readback" limits ctx.depth value.left) (
          left:
          computation.bind (quoteTypeAt limits ctx left) (
            quotedLeft:
            computation.bind (semantic.demand "readback" limits ctx.depth value.right) (
              right:
              computation.bind (quoteTypeAt limits ctx right) (
                quotedRight: emit limits ctx.depth (r.sumType quotedLeft quotedRight)
              )
            )
          )
        )
      else if value.kind == "pi" || value.kind == "sigma" then
        computation.bind (semantic.demand "readback" limits ctx.depth value.domain) (
          domain:
          computation.bind (quoteTypeAt limits ctx domain) (
            quotedDomain:
            computation.bind (context.extendComputed "readback" limits ctx domain) (
              extended:
              computation.bind
                (semantic.apply "readback" limits (ctx.depth + 1) value.codomain (
                  sem.valueCell (sem.neutral ctx.depth)
                ))
                (
                  body:
                  computation.bind (quoteTypeAt limits extended body) (
                    quotedBody:
                    emit limits ctx.depth ((if value.kind == "pi" then r.pi else r.sigma) quotedDomain quotedBody)
                  )
                )
            )
          )
        )
      else if value.kind == "identity-type" then
        computation.bind (semantic.demand "readback" limits ctx.depth value.carrier) (
          carrier:
          computation.bind (quoteTypeAt limits ctx carrier) (
            quotedCarrier:
            computation.bind (semantic.demand "readback" limits ctx.depth value.left) (
              left:
              computation.bind (quoteValue limits ctx carrier left) (
                quotedLeft:
                computation.bind (semantic.demand "readback" limits ctx.depth value.right) (
                  right:
                  computation.bind (quoteValue limits ctx carrier right) (
                    quotedRight: emit limits ctx.depth (r.identityType quotedCarrier quotedLeft quotedRight)
                  )
                )
              )
            )
          )
        )
      else if value.kind == "neutral" then
        quoteNeutral limits ctx value
      else
        computation.fail (result.internal "readback" ctx.depth result.codes.expectedType)
    );
  quoteValue =
    limits: ctx: type: value:
    budget.protect "readback" limits "quoteValue" ctx.depth (
      _paid:
      let
        typeChecked = representation.semanticShape type;
        valueChecked = representation.semanticShape value;
      in
      if !typeChecked.ok then
        computation.fail (malformed ctx.depth typeChecked)
      else if !valueChecked.ok then
        computation.fail (malformed ctx.depth valueChecked)
      else if type.kind == "universe" then
        quoteTypeAt limits ctx value
      else if type.kind == "pi" then
        computation.bind (semantic.demand "readback" limits ctx.depth type.domain) (
          domain:
          computation.bind (context.extendComputed "readback" limits ctx domain) (
            extended:
            let
              fresh = sem.neutral ctx.depth;
            in
            computation.bind (reflect limits ctx domain fresh) (
              argument:
              computation.bind (semantic.apply "readback" limits (ctx.depth + 1) value (sem.valueCell argument)) (
                body:
                computation.bind
                  (semantic.apply "readback" limits (ctx.depth + 1) type.codomain (sem.valueCell argument))
                  (
                    codomain:
                    computation.bind (quoteValue limits extended codomain body) (
                      quoted: emit limits ctx.depth (r.lambda quoted)
                    )
                  )
              )
            )
          )
        )
      else if type.kind == "sigma" then
        computation.bind (semantic.project "readback" limits ctx.depth "first" value) (
          first:
          computation.bind (semantic.demand "readback" limits ctx.depth type.domain) (
            domain:
            computation.bind (quoteValue limits ctx domain first) (
              quotedFirst:
              computation.bind (semantic.apply "readback" limits ctx.depth type.codomain (sem.valueCell first)) (
                codomain:
                computation.bind (semantic.project "readback" limits ctx.depth "second" value) (
                  second:
                  computation.bind (quoteValue limits ctx codomain second) (
                    quotedSecond: emit limits ctx.depth (r.pair quotedFirst quotedSecond)
                  )
                )
              )
            )
          )
        )
      else if type.kind == "unit-type" then
        emit limits ctx.depth r.unit
      else if type.kind == "sum-type" && value.kind == "left-injection" then
        computation.bind (semantic.demand "readback" limits ctx.depth type.left) (
          side:
          computation.bind (semantic.demand "readback" limits ctx.depth value.value) (
            payload:
            computation.bind (quoteValue limits ctx side payload) (
              quoted: emit limits ctx.depth (r.leftInjection quoted)
            )
          )
        )
      else if type.kind == "sum-type" && value.kind == "right-injection" then
        computation.bind (semantic.demand "readback" limits ctx.depth type.right) (
          side:
          computation.bind (semantic.demand "readback" limits ctx.depth value.value) (
            payload:
            computation.bind (quoteValue limits ctx side payload) (
              quoted: emit limits ctx.depth (r.rightInjection quoted)
            )
          )
        )
      else if type.kind == "identity-type" && value.kind == "refl" then
        computation.bind (semantic.demand "readback" limits ctx.depth type.carrier) (
          carrier:
          computation.bind (semantic.demand "readback" limits ctx.depth value.value) (
            witness:
            computation.bind (quoteValue limits ctx carrier witness) (
              quoted: emit limits ctx.depth (r.refl quoted)
            )
          )
        )
      else if value.kind == "neutral" then
        quoteNeutral limits ctx value
      else
        computation.fail (result.internal "readback" ctx.depth result.codes.malformedSemantic)
    );
  reify = quoteValue;
  finish =
    kind: ctx: executed:
    if !executed.ok then
      executed
    else
      let
        envelope = r.envelope ctx.depth executed.value [ ];
        admitted = core.operations.admitted envelope;
      in
      if !admitted.ok then
        result.internal kind ctx.depth result.codes.impossibleState
      else if kind == "readback" then
        result.readback {
          inherit (admitted) value;
          resources = representation.resources executed.state;
        }
      else
        result.quotation {
          inherit (admitted) value;
          resources = representation.resources executed.state;
        };
  runAt =
    judgment: ctx: state: program:
    if !context.validate ctx then
      result.internal judgment 0 result.codes.malformedContext
    else
      semantic.run { inherit judgment state program; };
  quoteAt =
    {
      contextValue,
      type,
      value,
      state,
      limits,
    }:
    runAt "readback" contextValue state (reify limits contextValue type value);
  quote =
    {
      contextValue,
      type,
      value,
      limits ? { },
    }:
    let
      resolved = budget.merge limits;
      executed =
        if resolved.ok then
          runAt "readback" contextValue budget.initial (reify resolved.value contextValue type value)
        else
          resolved;
    in
    finish "readback" contextValue executed;
  quoteType =
    {
      contextValue,
      value,
      limits ? { },
    }:
    let
      resolved = budget.merge limits;
      executed =
        if resolved.ok then
          runAt "quotation" contextValue budget.initial (quoteTypeAt resolved.value contextValue value)
        else
          resolved;
    in
    finish "quotation" contextValue executed;
  normalize = quote;
in
{
  inherit
    reflect
    reify
    quote
    quoteAt
    quoteType
    normalize
    ;
}
