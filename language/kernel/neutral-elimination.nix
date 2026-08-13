{
  evaluation,
  flow,
  semanticOps,
}:
let
  semantic = evaluation.representation;
  kinds = builtins.attrNames evaluation.representation.schema.spineItemFields;
  typeKinds = {
    application = "pi";
    "first-projection" = "sigma";
    "second-projection" = "sigma";
    "sum-elimination" = "sum-type";
    "unit-elimination" = "unit-type";
    "empty-elimination" = "empty-type";
    "identity-elimination" = "identity-type";
  };
  inventoriesAgree = builtins.attrNames typeKinds == kinds;
  makePlan =
    {
      item,
      type,
      value,
      limits,
      ctx,
    }:
    let
      inherit (ctx) depth;
      nextValue = semantic.extendNeutral value item;
      common = {
        inherit
          item
          type
          value
          nextValue
          limits
          ctx
          depth
          ;
      };
      plans = {
        application = common // {
          domain = state: semanticOps.demand limits state depth type.domain;
          argument = state: semanticOps.demand limits state depth item.argument;
          codomain =
            state: argument: semanticOps.apply limits state depth type.codomain (semantic.valueCell argument);
        };
        "first-projection" = common // {
          resultType = state: semanticOps.demand limits state depth type.domain;
        };
        "second-projection" = common // {
          first = state: semanticOps.project limits state depth "first" value;
          resultType =
            state: first: semanticOps.apply limits state depth type.codomain (semantic.valueCell first);
        };
        "sum-elimination" = common // {
          motiveContext = state: semanticOps.extendContext limits state ctx type;
          motiveAt =
            state: level: subject:
            semanticOps.apply limits state level item.motive (semantic.valueCell subject);
          sideType = state: side: semanticOps.demand limits state depth type.${side};
          sideContext = state: sideType: semanticOps.extendContext limits state ctx sideType;
          branchValue =
            state: level: branch: subject:
            semanticOps.apply limits state level branch (semantic.valueCell subject);
          resultType = state: semanticOps.apply limits state depth item.motive (semantic.valueCell value);
        };
        "unit-elimination" = common // {
          motiveContext = state: semanticOps.extendContext limits state ctx semantic.unitType;
          motiveAt =
            state: level: subject:
            semanticOps.apply limits state level item.motive (semantic.valueCell subject);
          caseValue = state: semanticOps.demand limits state depth item.case;
          resultType = state: semanticOps.apply limits state depth item.motive (semantic.valueCell value);
        };
        "empty-elimination" = common // {
          motiveContext = state: semanticOps.extendContext limits state ctx semantic.emptyType;
          motiveAt =
            state: level: subject:
            semanticOps.apply limits state level item.motive (semantic.valueCell subject);
          resultType = state: semanticOps.apply limits state depth item.motive (semantic.valueCell value);
        };
        "identity-elimination" = common // {
          carrier = state: semanticOps.demand limits state depth type.carrier;
          endpoint = state: side: semanticOps.demand limits state depth type.${side};
          extend =
            state: contextValue: valueType:
            semanticOps.extendContext limits state contextValue valueType;
          motiveAt =
            state: level: arguments:
            semanticOps.applyMany limits state level item.motive arguments;
          branchValue =
            state: level: witness:
            semanticOps.apply limits state level item.reflBranch (semantic.valueCell witness);
          resultType = state: arguments: semanticOps.applyMany limits state depth item.motive arguments;
        };
      };
    in
    plans.${item.kind};
in
{
  inherit kinds typeKinds inventoriesAgree;
  admit =
    item:
    let
      observed = builtins.tryEval (
        builtins.isAttrs item && item ? kind && builtins.isString item.kind && builtins.elem item.kind kinds
      );
    in
    observed.success && observed.value;
  transition =
    {
      item,
      type,
      value,
      limits,
      ctx,
      handlers,
      malformed,
      mismatch,
      peerItem ? null,
      peerValue ? null,
    }:
    let
      itemKnown =
        builtins.isAttrs item
        && item ? kind
        && builtins.isString item.kind
        && builtins.elem item.kind kinds;
      handlerKinds = builtins.attrNames handlers;
      handlersClosed = handlerKinds == kinds;
      pairing = itemKnown && builtins.isAttrs type && type ? kind && type.kind == typeKinds.${item.kind};
      selected = if itemKnown && builtins.hasAttr item.kind handlers then handlers.${item.kind} else null;
      prepared =
        if pairing then
          {
            plan = makePlan {
              inherit
                item
                type
                value
                limits
                ctx
                ;
            };
            peerPlan =
              if peerItem == null then
                null
              else
                makePlan {
                  item = peerItem;
                  inherit type;
                  value = peerValue;
                  inherit limits ctx;
                };
          }
        else
          null;
    in
    if !inventoriesAgree || !handlersClosed || !itemKnown || selected == null then
      malformed
    else if !pairing then
      mismatch
    else
      flow.andThen {
        ok = true;
        value = prepared;
      } (_: selected prepared);
}
