{
  result,
  logismos,
}:
let
  publicNames = {
    single = {
      nodes = 1;
      depth = 1;
    };
    shallow = {
      nodes = 8;
      depth = 4;
    };
    standard = {
      nodes = 256;
      depth = 32;
    };
  };
  planSpec = {
    nodes = 256;
    depth = 64;
  };
  algebra = logismos.budget.make {
    dimensions = [
      "depth"
      "nodes"
    ];
    namedCosts = {
      node = {
        depth = 0;
        nodes = 1;
      };
    };
  };
in
{
  names = publicNames;
  inherit planSpec algebra;
  initial = algebra.zero;

  resolve =
    {
      operation,
      path,
      name,
    }:
    let
      checked = builtins.tryEval (
        let
          valid = builtins.isString name && builtins.hasAttr name publicNames;
          observed = if builtins.isString name then name else builtins.typeOf name;
        in
        builtins.seq valid (builtins.seq observed { inherit valid observed; })
      );
    in
    if !checked.success then
      result.hostFailure {
        inherit operation path;
        guardedOperation = "budget-name-validation";
      }
    else if checked.value.valid then
      result.success {
        inherit operation path;
        policy = "budget";
        category = null;
        payload = publicNames.${name};
      }
    else
      result.mismatch {
        inherit operation path;
        expected = "named-traversal-budget";
        observed = checked.value.observed;
      };

  charge =
    {
      operation,
      path,
      budgetName,
      budget,
      state,
      depth,
    }:
    let
      valid = algebra.valid state;
      attempted = if valid then algebra.maximumDepth state depth else state;
    in
    if !valid then
      {
        ok = false;
        failure = result.internalBug {
          inherit operation path;
          code = result.codes.budgetUnderflow;
          context = {
            consumed = state.nodes or null;
          };
        };
      }
    else if depth > budget.depth then
      {
        ok = false;
        failure = result.exhausted {
          inherit operation path;
          budget = budgetName;
          dimension = "depth";
          limit = budget.depth;
          consumed = state.nodes;
        };
      }
    else if state.nodes >= budget.nodes then
      {
        ok = false;
        failure = result.exhausted {
          inherit operation path;
          budget = budgetName;
          dimension = "nodes";
          limit = budget.nodes;
          consumed = state.nodes;
        };
      }
    else
      {
        ok = true;
        state = algebra.add attempted algebra.namedCosts.node;
      };
}
