let
  lists = import ../internal/lists.nix;
  inherit (lists) reverse;
  limits = {
    nodes = 256;
    depth = 64;
    fuel = 4096;
  };
  codes = {
    missingEnvironmentLevel = "AXIOM-EVAL-001";
    unknownTerm = "AXIOM-EVAL-002";
    invalidSemanticValue = "AXIOM-EVAL-003";
    impossibleMachineState = "AXIOM-EVAL-004";
    invalidEnvironmentCell = "AXIOM-EVAL-005";
    staleSemanticGeneration = "AXIOM-EVAL-006";
    invalidLimits = "AXIOM-EVAL-007";
  };
  internalBug = code: context: {
    ok = false;
    kind = "internal-bug";
    inherit code context;
  };
  resolveLimits =
    supplied:
    let
      checked = builtins.tryEval (
        builtins.isAttrs supplied
        && builtins.all (name: builtins.hasAttr name limits) (builtins.attrNames supplied)
        && builtins.all (name: builtins.isInt supplied.${name} && supplied.${name} >= 0) (
          builtins.attrNames supplied
        )
      );
    in
    if checked.success && checked.value then
      {
        ok = true;
        value = limits // supplied;
      }
    else
      {
        ok = false;
        failure = internalBug codes.invalidLimits { };
      };
in
{
  inherit
    limits
    codes
    internalBug
    resolveLimits
    ;
  emit = state: event: state // { trace = [ event ] ++ state.trace; };
  success = value: state: {
    ok = true;
    kind = "success";
    inherit value;
    nodes = state.usage.nodes;
    trace = reverse state.trace;
  };
  machineSuccess = value: state: {
    ok = true;
    kind = "success";
    inherit value;
    nodes = state.usage.nodes;
    fuel = state.usage.fuel;
    trace = reverse state.trace;
  };
  exhausted = dimension: limit: consumed: {
    ok = false;
    kind = "resource-exhaustion";
    budget = "evaluation";
    inherit dimension limit consumed;
  };
}
