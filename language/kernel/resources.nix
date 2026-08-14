{
  logismos,
  representation,
  result,
}:
let
  inherit (logismos) computation;
  dimensions = [
    "checking"
    "comparison"
    "context"
    "conversion"
    "depth"
    "output"
    "readback"
  ];
  zeroCost = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = 0;
    }) dimensions
  );
  cost = name: amount: zeroCost // { ${name} = amount; };
  algebra = logismos.budget.make {
    inherit dimensions;
    namedCosts = builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = cost name 1;
        })
        [
          "checking"
          "comparison"
          "context"
          "conversion"
          "output"
          "readback"
        ]
    );
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
  chargeAmount =
    judgment: limits: name: depth: amount:
    computation.bind computation.get (
      state:
      if !builtins.isInt amount || amount < 0 then
        computation.fail (result.internal judgment depth result.codes.impossibleState)
      else if depth > limits.depth then
        computation.fail (result.resource judgment depth "depth" limits.depth depth)
      else
        computation.bind
          (algebra.charge {
            limit = limit limits;
            usage = usage state;
            cost = cost name amount;
            refusal = result.resource judgment depth name limits.${name} state.${name};
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
in
{
  inherit
    algebra
    initial
    resolve
    chargeAmount
    ;
  merge = supplied: resolve "resources" 0 supplied;
  charge =
    judgment: limits: name: depth:
    chargeAmount judgment limits name depth 1;
}
