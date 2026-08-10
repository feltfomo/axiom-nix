let
  reverse = builtins.foldl' (values: value: [ value ] ++ values) [ ];
in
{
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
  };

  # traces prepend on the hot path and reverse once at the result boundary
  emit = state: event: state // { trace = [ event ] ++ state.trace; };

  success = value: state: {
    ok = true;
    kind = "success";
    inherit value;
    inherit (state) nodes;
    trace = reverse state.trace;
  };

  machineSuccess = value: state: {
    ok = true;
    kind = "success";
    inherit value;
    inherit (state) nodes fuel;
    trace = reverse state.trace;
  };

  exhausted = dimension: limit: consumed: {
    ok = false;
    kind = "resource-exhaustion";
    budget = "evaluation";
    inherit dimension limit consumed;
  };

  internalBug = code: context: {
    ok = false;
    kind = "internal-bug";
    inherit code context;
  };
}
