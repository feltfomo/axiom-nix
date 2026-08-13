{ representation, result }:
let
  names = builtins.attrNames representation.limits;
  initial = {
    readback = 0;
    output = 0;
    comparison = 0;
    conversion = 0;
    checking = 0;
    context = 0;
    depth = 0;
    forced = 0;
  };
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
  merge = supplied: resolve "resources" 0 supplied;
  charge =
    judgment: limits: budget: state: depth:
    if depth > limits.depth then
      result.resource judgment depth "depth" limits.depth depth
    else if state.${budget} >= limits.${budget} then
      result.resource judgment depth budget limits.${budget} state.${budget}
    else
      {
        ok = true;
        state = state // {
          ${budget} = state.${budget} + 1;
          depth = if depth > state.depth then depth else state.depth;
        };
      };
  chargeAmount =
    judgment: limits: budget: state: depth: amount:
    if !builtins.isInt amount || amount < 0 then
      result.internal judgment depth result.codes.impossibleState
    else if depth > limits.depth then
      result.resource judgment depth "depth" limits.depth depth
    else if state.${budget} + amount > limits.${budget} then
      result.resource judgment depth budget limits.${budget} state.${budget}
    else
      {
        ok = true;
        state = state // {
          ${budget} = state.${budget} + amount;
          depth = if depth > state.depth then depth else state.depth;
        };
      };
in
{
  inherit
    initial
    resolve
    merge
    charge
    chargeAmount
    ;
}
