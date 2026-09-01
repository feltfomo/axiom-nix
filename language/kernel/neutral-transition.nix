{
  evaluation,
  representation,
  result,
  context,
  semantic,
  budget,
  logismos,
  observer,
}:
let
  inherit (logismos) computation traversal;
  lists = import ../internal/lists.nix;
  inherit (lists) reverse;
  sem = evaluation.representation;
  kinds = builtins.attrNames sem.schema.spineItemFields;
  typeKinds = {
    application = "pi";
    "first-projection" = "sigma";
    "second-projection" = "sigma";
    "sum-elimination" = "sum-type";
    "unit-elimination" = "unit-type";
    "empty-elimination" = "empty-type";
    "identity-elimination" = "identity-type";
  };
  prepare =
    args:
    let
      itemShape = representation.spineItemShape args.item;
      typeShape = representation.semanticShape args.type;
      valueShape = representation.neutralShape args.value;
      paired = args.peerItem != null;
      peerItemShape = if paired then representation.spineItemShape args.peerItem else { ok = true; };
      peerValueShape = if paired then representation.neutralShape args.peerValue else { ok = true; };
      failed =
        if !itemShape.ok then
          itemShape
        else if !typeShape.ok then
          typeShape
        else if !valueShape.ok then
          valueShape
        else if !peerItemShape.ok then
          peerItemShape
        else
          peerValueShape;
      shapeFailure = result.internal args.judgment args.ctx.depth (
        if (failed.reason or "malformed") == "stale" then
          result.codes.staleGeneration
        else
          result.codes.malformedSemantic
      );
      compatible =
        itemShape.ok
        && builtins.hasAttr args.item.kind typeKinds
        && typeShape.ok
        && args.type.kind == typeKinds.${args.item.kind};
      peersMatch = !paired || (peerItemShape.ok && args.item.kind == args.peerItem.kind);
    in
    if builtins.attrNames typeKinds != kinds then
      computation.fail (result.internal args.judgment args.ctx.depth result.codes.impossibleState)
    else if
      !itemShape.ok || !typeShape.ok || !valueShape.ok || !peerItemShape.ok || !peerValueShape.ok
    then
      computation.fail shapeFailure
    else if !compatible || !peersMatch then
      computation.fail args.mismatch
    else
      computation.pure {
        inherit (args)
          judgment
          limits
          ctx
          item
          peerItem
          type
          value
          peerValue
          ;
        inherit paired;
        depth = args.ctx.depth;
      };
  paired =
    d: leftProgram: rightProgram:
    if d.paired then
      computation.bind leftProgram (left: computation.map (right: { inherit left right; }) rightProgram)
    else
      computation.map (left: {
        inherit left;
        right = null;
      }) leftProgram;
  applicationDomain = d: semantic.demand d.judgment d.limits d.depth d.type.domain;
  applicationArguments =
    d:
    paired d (semantic.demand d.judgment d.limits d.depth d.item.argument) (
      semantic.demand d.judgment d.limits d.depth d.peerItem.argument
    );
  sumMotive =
    d:
    computation.bind (context.extendComputed d.judgment d.limits d.ctx d.type) (
      motiveContext:
      let
        subject = sem.neutral d.depth;
      in
      computation.map (values: values // { context = motiveContext; }) (
        paired d (semantic.apply d.judgment d.limits (d.depth + 1) d.item.motive (sem.valueCell subject)) (
          semantic.apply d.judgment d.limits (d.depth + 1) d.peerItem.motive (sem.valueCell subject)
        )
      )
    );
  sumBranch =
    d: side:
    computation.bind (semantic.demand d.judgment d.limits d.depth d.type.${side}) (
      sideType:
      computation.bind (context.extendComputed d.judgment d.limits d.ctx sideType) (
        sideContext:
        let
          subject = sem.neutral d.depth;
          injected =
            if side == "left" then
              sem.leftInjection (sem.valueCell subject)
            else
              sem.rightInjection (sem.valueCell subject);
          leftBranch = if side == "left" then d.item.leftBranch else d.item.rightBranch;
          rightBranch = if side == "left" then d.peerItem.leftBranch else d.peerItem.rightBranch;
        in
        computation.bind
          (semantic.apply d.judgment d.limits (d.depth + 1) d.item.motive (sem.valueCell injected))
          (
            target:
            computation.map
              (
                values:
                values
                // {
                  context = sideContext;
                  inherit target;
                }
              )
              (
                paired d (semantic.apply d.judgment d.limits (d.depth + 1) leftBranch (sem.valueCell subject)) (
                  semantic.apply d.judgment d.limits (d.depth + 1) rightBranch (sem.valueCell subject)
                )
              )
          )
      )
    );
  unitMotive =
    d:
    computation.bind (context.extendComputed d.judgment d.limits d.ctx sem.unitType) (
      motiveContext:
      let
        subject = sem.neutral d.depth;
      in
      computation.map (values: values // { context = motiveContext; }) (
        paired d (semantic.apply d.judgment d.limits (d.depth + 1) d.item.motive (sem.valueCell subject)) (
          semantic.apply d.judgment d.limits (d.depth + 1) d.peerItem.motive (sem.valueCell subject)
        )
      )
    );
  unitCases =
    d:
    computation.bind (semantic.apply d.judgment d.limits d.depth d.item.motive (sem.valueCell sem.unit))
      (
        target:
        computation.map (values: values // { inherit target; }) (
          paired d (semantic.demand d.judgment d.limits d.depth d.item.case) (
            semantic.demand d.judgment d.limits d.depth d.peerItem.case
          )
        )
      );
  emptyMotive =
    d:
    computation.bind (context.extendComputed d.judgment d.limits d.ctx sem.emptyType) (
      motiveContext:
      let
        subject = sem.neutral d.depth;
      in
      computation.map (values: values // { context = motiveContext; }) (
        paired d (semantic.apply d.judgment d.limits (d.depth + 1) d.item.motive (sem.valueCell subject)) (
          semantic.apply d.judgment d.limits (d.depth + 1) d.peerItem.motive (sem.valueCell subject)
        )
      )
    );
  identityCarrier = d: semantic.demand d.judgment d.limits d.depth d.type.carrier;
  identityMotive =
    d:
    computation.bind (identityCarrier d) (
      carrier:
      computation.bind (context.extendComputed d.judgment d.limits d.ctx carrier) (
        sourceContext:
        let
          source = sem.neutral d.depth;
        in
        computation.bind (context.extendComputed d.judgment d.limits sourceContext carrier) (
          targetContext:
          let
            target = sem.neutral (d.depth + 1);
            evidenceType = sem.identityType (sem.valueCell carrier) (sem.valueCell source) (
              sem.valueCell target
            );
          in
          computation.bind (context.extendComputed d.judgment d.limits targetContext evidenceType) (
            motiveContext:
            let
              evidence = sem.neutral (d.depth + 2);
              arguments = [
                (sem.valueCell source)
                (sem.valueCell target)
                (sem.valueCell evidence)
              ];
            in
            computation.map
              (
                values:
                values
                // {
                  context = motiveContext;
                  inherit carrier;
                }
              )
              (
                paired d (semantic.applyMany d.judgment d.limits (d.depth + 3) d.item.motive arguments) (
                  semantic.applyMany d.judgment d.limits (d.depth + 3) d.peerItem.motive arguments
                )
              )
          )
        )
      )
    );
  identityBranches =
    d: carrier:
    computation.bind (context.extendComputed d.judgment d.limits d.ctx carrier) (
      branchContext:
      let
        witness = sem.neutral d.depth;
        arguments = [
          (sem.valueCell witness)
          (sem.valueCell witness)
          (sem.valueCell (sem.refl (sem.valueCell witness)))
        ];
      in
      computation.bind (semantic.applyMany d.judgment d.limits (d.depth + 1) d.item.motive arguments) (
        target:
        computation.map
          (
            values:
            values
            // {
              context = branchContext;
              inherit target;
            }
          )
          (
            paired d (semantic.apply d.judgment d.limits (d.depth + 1) d.item.reflBranch (
              sem.valueCell witness
            )) (semantic.apply d.judgment d.limits (d.depth + 1) d.peerItem.reflBranch (sem.valueCell witness))
          )
      )
    );
  advance =
    d:
    let
      finish =
        nextType:
        computation.pure {
          type = nextType;
          value = sem.extendNeutral d.value d.item;
          peerValue = if d.paired then sem.extendNeutral d.peerValue d.peerItem else null;
        };
    in
    if d.item.kind == "application" then
      computation.bind (semantic.apply d.judgment d.limits d.depth d.type.codomain d.item.argument) finish
    else if d.item.kind == "first-projection" then
      computation.bind (semantic.demand d.judgment d.limits d.depth d.type.domain) finish
    else if d.item.kind == "second-projection" then
      computation.bind (semantic.project d.judgment d.limits d.depth "first" d.value) (
        first:
        computation.bind (semantic.apply d.judgment d.limits d.depth d.type.codomain (
          sem.valueCell first
        )) finish
      )
    else if
      d.item.kind == "sum-elimination"
      || d.item.kind == "unit-elimination"
      || d.item.kind == "empty-elimination"
    then
      computation.bind (semantic.apply d.judgment d.limits d.depth d.item.motive (
        sem.valueCell d.value
      )) finish
    else
      computation.bind (semantic.demand d.judgment d.limits d.depth d.type.left) (
        source:
        computation.bind (semantic.demand d.judgment d.limits d.depth d.type.right) (
          target:
          computation.bind (semantic.applyMany d.judgment d.limits d.depth d.item.motive [
            (sem.valueCell source)
            (sem.valueCell target)
            (sem.valueCell d.value)
          ]) finish
        )
      );
  observePhase =
    descriptor: observation:
    let
      checked = builtins.tryEval (
        builtins.isAttrs observation
        &&
          builtins.attrNames observation == [
            "phase"
            "value"
          ]
        && observation.phase == "observed"
      );
    in
    if !checked.success || !checked.value then
      computation.fail (result.internal descriptor.judgment descriptor.depth result.codes.impossibleState)
    else
      computation.pure {
        phase = "observed";
        inherit descriptor;
        observer = observation.value;
      };
  replay =
    { observe, ... }@args:
    let
      pairedReplay = args.peerSpine != null;
      countChecked = builtins.tryEval (
        builtins.isList args.spine
        && builtins.isInt args.spineCount
        && args.spineCount >= 0
        && builtins.length args.spine == args.spineCount
        && (
          !pairedReplay
          || (
            builtins.isList args.peerSpine
            && builtins.isInt args.peerSpineCount
            && args.peerSpineCount >= 0
            && builtins.length args.peerSpine == args.peerSpineCount
            && args.peerSpineCount == args.spineCount
          )
        )
      );
      totalCount = args.spineCount + (if pairedReplay then args.peerSpineCount else 0);
      writtenSpine = reverse args.spine;
      writtenPeerSpine = if pairedReplay then reverse args.peerSpine else [ ];
      stepsProgram =
        if pairedReplay then
          traversal.zipFold {
            left = writtenSpine;
            right = writtenPeerSpine;
            inherit (args) mismatch;
            combine = item: peerItem: computation.pure { inherit item peerItem; };
          }
        else
          computation.pure (
            map (item: {
              inherit item;
              peerItem = null;
            }) writtenSpine
          );
      initial = {
        type = args.initial.type;
        value = args.initial.value;
        inherit (args) peerValue;
        observer = args.initial.observer or null;
      };
      replayProgram = computation.bind stepsProgram (
        steps:
        builtins.foldl' (
          current: step:
          computation.bind current (
            state:
            computation.bind
              (observer.emit { operation = "kernel.transition.typed-neutral"; } (prepare {
                inherit (args)
                  judgment
                  limits
                  ctx
                  mismatch
                  ;
                inherit (step) item peerItem;
                inherit (state)
                  type
                  value
                  peerValue
                  ;
              }))
              (
                descriptor:
                computation.bind (observe descriptor state.observer) (
                  value:
                  computation.bind
                    (observePhase descriptor {
                      phase = "observed";
                      inherit value;
                    })
                    (
                      observed:
                      computation.map (
                        next:
                        next
                        // {
                          inherit (observed) observer;
                        }
                      ) (advance observed.descriptor)
                    )
                )
              )
          )
        ) (computation.pure initial) steps
      );
    in
    if !countChecked.success || !countChecked.value then
      computation.fail args.malformed
    else
      computation.bind (budget.chargeAmount args.judgment args.limits args.budgetName args.ctx.depth
        totalCount
      ) (_spine: replayProgram);
in
{
  inherit
    kinds
    typeKinds
    prepare
    applicationDomain
    applicationArguments
    sumMotive
    sumBranch
    unitMotive
    unitCases
    emptyMotive
    identityMotive
    identityBranches
    advance
    observePhase
    replay
    ;
}
