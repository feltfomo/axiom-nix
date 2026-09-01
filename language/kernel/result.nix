{ representation, core }:
let
  resource = judgment: depth: budget: limit: consumed: {
    ok = false;
    inherit (representation) generation;
    kind = "resource-exhaustion";
    code = "AXIOM-KERNEL-001";
    inherit
      judgment
      depth
      budget
      limit
      consumed
      ;
    path = [ ];
    expected = null;
    received = null;
  };
  failure = judgment: depth: code: path: expected: received: {
    ok = false;
    inherit (representation) generation;
    kind = "judgment-failure";
    inherit
      judgment
      depth
      code
      path
      expected
      received
      ;
    resource = null;
  };
  internal = judgment: depth: code: {
    ok = false;
    inherit (representation) generation;
    kind = "internal-failure";
    inherit judgment depth code;
    path = [ ];
    expected = null;
    received = null;
    resource = null;
  };
  trusted =
    kind: fields:
    {
      ok = true;
      inherit (representation) generation;
      inherit kind;
    }
    // fields;
  canonical =
    value:
    let
      outer = builtins.tryEval (
        representation.exact [ "generation" "metadata" "root" "scope" ] value
        && value.generation == core.representation.generation
        && builtins.isInt value.scope
        && value.scope >= 0
        && value.metadata == [ ]
      );
      admitted = if outer.success && outer.value then core.operations.admitted value else { ok = false; };
    in
    outer.success && outer.value && admitted.ok && admitted.value.metadata == [ ];
  semantic = value: representation.semanticTreeShape 0 value;
  base =
    kind: names: value:
    representation.generationMatches value
    && representation.exact (builtins.sort builtins.lessThan (
      [
        "generation"
        "kind"
        "ok"
      ]
      ++ names
    )) value
    && value.ok == true
    && value.kind == kind;
  checkedContext = { context, resources }: trusted "checked-context" { inherit context resources; };
  formation =
    {
      level,
      type,
      resources,
    }:
    trusted "formation" { inherit level type resources; };
  inference =
    {
      type,
      value,
      resources,
    }:
    trusted "inference" { inherit type value resources; };
  checking =
    {
      type,
      value,
      resources,
    }:
    trusted "checking" { inherit type value resources; };
  typeConversion = { resources }: trusted "type-conversion" { inherit resources; };
  termConversion =
    {
      type,
      resources,
      observations,
    }:
    trusted "term-conversion" { inherit type resources observations; };
  readback = { value, resources }: trusted "readback" { inherit value resources; };
  quotation = { value, resources }: trusted "quotation" { inherit value resources; };
  oracle =
    {
      left,
      right,
      resources,
    }:
    trusted "conversion-oracle" { inherit left right resources; };
  validators = {
    checkedContext =
      value:
      base "checked-context" [ "context" "resources" ] value
      && representation.contextShape value.context
      && representation.validResources value.resources;
    formation =
      value:
      base "formation" [ "level" "resources" "type" ] value
      && semantic value.type
      && representation.validResources value.resources;
    inference =
      value:
      base "inference" [ "resources" "type" "value" ] value
      && semantic value.type
      && semantic value.value
      && representation.validResources value.resources;
    checking =
      value:
      base "checking" [ "resources" "type" "value" ] value
      && semantic value.type
      && semantic value.value
      && representation.validResources value.resources;
    typeConversion =
      value:
      base "type-conversion" [ "resources" ] value && representation.validResources value.resources;
    termConversion =
      value:
      base "term-conversion" [ "observations" "resources" "type" ] value
      && semantic value.type
      && representation.validResources value.resources
      && representation.exact [ "forced" ] value.observations
      && builtins.isInt value.observations.forced
      && value.observations.forced >= 0;
    readback =
      value:
      base "readback" [ "resources" "value" ] value
      && canonical value.value
      && representation.validResources value.resources;
    quotation =
      value:
      base "quotation" [ "resources" "value" ] value
      && canonical value.value
      && representation.validResources value.resources;
    oracle =
      value:
      base "conversion-oracle" [ "left" "resources" "right" ] value
      && canonical value.left
      && canonical value.right
      && representation.validResources value.resources;
  };
in
{
  inherit
    resource
    failure
    internal
    checkedContext
    formation
    inference
    checking
    typeConversion
    termConversion
    readback
    quotation
    oracle
    validators
    ;
  codes = {
    mismatch = "AXIOM-KERNEL-002";
    malformedContext = "AXIOM-KERNEL-003";
    staleGeneration = "AXIOM-KERNEL-004";
    outOfScope = "AXIOM-KERNEL-005";
    expectedType = "AXIOM-KERNEL-006";
    cannotInfer = "AXIOM-KERNEL-007";
    impossibleState = "AXIOM-KERNEL-008";
    evaluation = "AXIOM-KERNEL-009";
    malformedSemantic = "AXIOM-KERNEL-010";
    malformedLimits = "AXIOM-KERNEL-011";
  };
}
