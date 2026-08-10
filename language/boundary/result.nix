let
  exact = names: value: builtins.isAttrs value && builtins.attrNames value == names;
  validPath = path: builtins.isList path && builtins.all builtins.isString path;
  validCategory = category: category == null || builtins.isString category;

  check =
    value:
    if !(builtins.isAttrs value && value ? kind && builtins.isString value.kind) then
      false
    else if value.kind == "success" then
      exact [
        "category"
        "kind"
        "operation"
        "path"
        "payload"
        "policy"
      ] value
      && builtins.isString value.operation
      && validPath value.path
      && builtins.isString value.policy
      && validCategory value.category
    else if value.kind == "boundary-mismatch" then
      exact [
        "expected"
        "kind"
        "observed"
        "operation"
        "path"
      ] value
      && builtins.isString value.operation
      && validPath value.path
      && builtins.isString value.expected
      && builtins.isString value.observed
    else if value.kind == "host-failure" then
      exact [
        "guardedOperation"
        "kind"
        "operation"
        "path"
      ] value
      && builtins.isString value.operation
      && validPath value.path
      && builtins.isString value.guardedOperation
    else if value.kind == "resource-exhaustion" then
      exact [
        "budget"
        "consumed"
        "dimension"
        "kind"
        "limit"
        "operation"
        "path"
      ] value
      && builtins.isString value.operation
      && validPath value.path
      && builtins.isString value.budget
      && builtins.elem value.dimension [
        "depth"
        "nodes"
      ]
      && builtins.isInt value.limit
      && builtins.isInt value.consumed
    else if value.kind == "internal-bug" then
      exact [
        "code"
        "context"
        "kind"
        "operation"
        "path"
      ] value
      && builtins.isString value.operation
      && validPath value.path
      && builtins.isString value.code
      && builtins.isAttrs value.context
    else
      false;
in
{
  codes = {
    unknownPolicyDispatch = "AXIOM-HOST-001";
    unknownPlanDispatch = "AXIOM-HOST-002";
    budgetUnderflow = "AXIOM-HOST-003";
    impossibleTraversal = "AXIOM-HOST-004";
    unknownHostCategory = "AXIOM-HOST-005";
  };

  success =
    {
      operation,
      path,
      policy,
      category,
      payload,
    }:
    {
      kind = "success";
      inherit
        operation
        path
        policy
        category
        payload
        ;
    };

  mismatch =
    {
      operation,
      path,
      expected,
      observed,
    }:
    {
      kind = "boundary-mismatch";
      inherit
        operation
        path
        expected
        observed
        ;
    };

  hostFailure =
    {
      operation,
      path,
      guardedOperation,
    }:
    {
      kind = "host-failure";
      inherit operation path guardedOperation;
    };

  exhausted =
    {
      operation,
      path,
      budget,
      dimension,
      limit,
      consumed,
    }:
    {
      kind = "resource-exhaustion";
      inherit
        operation
        path
        budget
        dimension
        limit
        consumed
        ;
    };

  internalBug =
    {
      operation,
      path,
      code,
      context,
    }:
    {
      kind = "internal-bug";
      inherit
        operation
        path
        code
        context
        ;
    };

  isResult =
    value:
    let
      checked = builtins.tryEval (check value);
    in
    checked.success && checked.value;
}
