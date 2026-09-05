{
  logismos,
  representation,
  result,
}:
let
  inherit (logismos) computation;
  dimensions = [
    "application"
    "checking"
    "comparison"
    "context"
    "conversion"
    "demand"
    "depth"
    "output"
    "projection"
    "readback"
    "transition"
  ];
  zeroCost = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = 0;
    }) dimensions
  );
  cost = dimension: zeroCost // { ${dimension} = 1; };
  costDimensions = {
    applyArgument = "application";
    checkTerm = "checking";
    compareNeutral = "comparison";
    compareTerm = "comparison";
    compareType = "comparison";
    demandCell = "demand";
    emitSyntaxNode = "output";
    enterTermConversion = "conversion";
    enterTypeConversion = "conversion";
    inferTerm = "checking";
    insertContextEntry = "context";
    projectValue = "projection";
    quoteNeutral = "readback";
    quoteType = "readback";
    quoteValue = "readback";
    replayItem = "transition";
  };
  # complete vectors keep callers from assigning an operation to a convenient bucket
  namedCosts = builtins.mapAttrs (_name: cost) costDimensions;
  algebra = logismos.budget.make {
    inherit dimensions namedCosts;
  };
  names = builtins.attrNames representation.limits;
  initial = algebra.zero // {
    forced = 0;
  };
  usage =
    state:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = state.${name};
      }) dimensions
    );
  limit =
    limits:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = limits.${name};
      }) dimensions
    );
  resolve =
    judgment: depth: supplied:
    let
      checked = builtins.tryEval (
        builtins.isAttrs supplied
        && builtins.all (name: builtins.elem name names) (builtins.attrNames supplied)
        && builtins.all (name: builtins.isInt supplied.${name} && supplied.${name} >= 0) (
          builtins.attrNames supplied
        )
      );
    in
    if checked.success && checked.value then
      {
        ok = true;
        value = representation.limits // supplied;
      }
    else
      result.internal judgment depth result.codes.malformedLimits;
  scale =
    amount: vector:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = vector.${name} * amount;
      }) dimensions
    );
  chargeNamedAmount =
    judgment: limits: costName: depth: amount:
    computation.bind computation.get (
      state:
      if !builtins.isString costName || !(builtins.hasAttr costName namedCosts) then
        computation.fail (result.internal judgment depth result.codes.impossibleState)
      else if !builtins.isInt amount || amount < 0 then
        computation.fail (result.internal judgment depth result.codes.impossibleState)
      else if depth > limits.depth then
        computation.fail (result.resource judgment depth "depth" limits.depth depth)
      else
        let
          dimension = costDimensions.${costName};
          # scaling records repeated instances of one operation without opening the protected work
          scaled = scale amount namedCosts.${costName};
        in
        computation.bind
          (algebra.charge {
            limit = limit limits;
            usage = usage state;
            cost = scaled;
            # refusal reports the state before the operation because none of its protected work ran
            refusal = result.resource judgment depth dimension limits.${dimension} state.${dimension};
          })
          (
            charged:
            computation.bind (computation.modify (
              current:
              current
              // charged
              // {
                forced = current.forced or 0;
                depth = if depth > charged.depth then depth else charged.depth;
              }
            )) (_unit: computation.pure null)
          )
    );
  chargeNamed =
    judgment: limits: costName: depth:
    chargeNamedAmount judgment limits costName depth 1;
  protect =
    judgment: limits: costName: depth: protected:
    computation.bind (chargeNamed judgment limits costName depth) protected;
in
{
  inherit
    algebra
    namedCosts
    initial
    resolve
    chargeNamed
    chargeNamedAmount
    protect
    ;
  merge = supplied: resolve "resources" 0 supplied;
}
