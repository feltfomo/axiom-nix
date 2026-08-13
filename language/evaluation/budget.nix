{
  result,
  logismos,
}:
let
  algebra = logismos.budget.make {
    dimensions = [
      "depth"
      "fuel"
      "nodes"
    ];
    namedCosts = {
      semanticNode = {
        depth = 0;
        fuel = 0;
        nodes = 1;
      };
      machineStep = {
        depth = 0;
        fuel = 1;
        nodes = 0;
      };
    };
  };
  limitVector = limits: {
    inherit (limits) depth fuel nodes;
  };
in
{
  inherit algebra;
  initial = algebra.zero;

  semanticNode =
    {
      limits,
      usage,
      depth,
    }:
    let
      attempted = algebra.maximumDepth usage depth;
    in
    if depth > limits.depth then
      {
        ok = false;
        failure = result.exhausted "depth" limits.depth usage.nodes;
      }
    else if usage.nodes >= limits.nodes then
      {
        ok = false;
        failure = result.exhausted "nodes" limits.nodes usage.nodes;
      }
    else
      {
        ok = true;
        usage = algebra.add attempted algebra.namedCosts.semanticNode;
      };

  machineStep =
    {
      limits,
      usage,
    }:
    if usage.fuel >= limits.fuel then
      {
        ok = false;
        failure = result.exhausted "fuel" limits.fuel usage.fuel;
      }
    else
      {
        ok = true;
        usage = algebra.add usage algebra.namedCosts.machineStep;
      };

  remaining = limits: usage: algebra.remaining (limitVector limits) usage;
}
