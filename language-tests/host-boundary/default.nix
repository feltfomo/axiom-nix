{ language }:
let
  inherit (language) boundary;
  inherit (boundary) result;
  poison = import ./poison.nix;

  categoryPlan = category: {
    kind = "category";
    inherit category;
  };
  opaquePlan = {
    kind = "opaque";
  };
  listPlan = element: {
    kind = "list";
    inherit element;
  };
  attrsPlan = fields: {
    kind = "attrs";
    inherit fields;
  };
  fieldPlan = name: plan: { inherit name plan; };

  nestValue = count: if count == 0 then 1 else [ (nestValue (count - 1)) ];
  nestValueTail = count: tail: if count == 0 then tail else [ (nestValueTail (count - 1) tail) ];
  nestPlan = count: if count == 0 then categoryPlan "int" else listPlan (nestPlan (count - 1));
  nestPlanTail = count: tail: if count == 0 then tail else listPlan (nestPlanTail (count - 1) tail);
  nestAttrPlan =
    count:
    if count == 0 then
      categoryPlan "int"
    else
      attrsPlan [ (fieldPlan "next" (nestAttrPlan (count - 1))) ];
  nestAttrValue = count: if count == 0 then 1 else { next = nestAttrValue (count - 1); };
  generatedFields =
    count: builtins.genList (index: fieldPlan "f${toString index}" (categoryPlan "int")) count;
  generatedSelections =
    count:
    builtins.genList (index: {
      name = "f${toString index}";
      category = "int";
    }) count;
  generatedValues =
    count:
    builtins.listToAttrs (
      builtins.genList (index: {
        name = "f${toString index}";
        value = index;
      }) count
    );

  outerSamples = [
    {
      value = null;
      category = "null";
    }
    {
      value = true;
      category = "bool";
    }
    {
      value = 1;
      category = "int";
    }
    {
      value = 1.5;
      category = "float";
    }
    {
      value = "value";
      category = "string";
    }
    {
      value = ./poison.nix;
      category = "path";
    }
    {
      value = [ ];
      category = "list";
    }
    {
      value = { };
      category = "attrs";
    }
    {
      value = _value: null;
      category = "function";
    }
  ];
  outerCategoriesPass = builtins.all (
    sample:
    let
      observed = boundary.observeOuter sample.value;
    in
    observed.kind == "success" && observed.category == sample.category
  ) outerSamples;

  opaquePoison = boundary.observeOpaque poison.poison;
  outerPoison = boundary.observeOuter poison.poison;
  outerLazyAttrs = boundary.observeOuter poison.poisonedAttrs;
  outerInactive = boundary.observeOuter (if true then 1 else poison.poison);
  outerDerivation = boundary.observeOuter poison.derivation;
  outerContextString = boundary.observeOuter poison.contextString;
  outerDivergentCallback = boundary.observeOuter poison.divergentCallback;

  listSpine = boundary.observeSpine {
    name = "shallow";
    value = poison.poisonedList;
  };
  attrsSpine = boundary.observeSpine {
    name = "shallow";
    value = poison.poisonedAttrs;
  };
  exactSpine = boundary.observeSpine {
    name = "shallow";
    value = [
      poison.poison
      poison.poison
      poison.poison
      poison.poison
      poison.poison
      poison.poison
      poison.poison
    ];
  };
  overSpine = boundary.observeSpine {
    name = "shallow";
    value = [
      poison.poison
      poison.poison
      poison.poison
      poison.poison
      poison.poison
      poison.poison
      poison.poison
      poison.poison
    ];
  };
  largeSpine = boundary.observeSpine {
    name = "single";
    value = builtins.genList (_index: poison.poison) 1000;
  };
  poisonedBudgetName = boundary.observeSpine {
    name = poison.poison;
    value = [ ];
  };
  planSpineBudget = boundary.observeSpine {
    name = "plan";
    value = [ ];
  };
  planFieldBudget = boundary.observeFields {
    name = "plan";
    fields = [ ];
    value = { };
  };
  planDeepBudget = boundary.observeDeep {
    name = "plan";
    plan = opaquePlan;
    value = poison.poison;
  };

  selectedOrder = boundary.observeFields {
    name = "shallow";
    fields = [
      {
        name = "b";
        category = "int";
      }
      {
        name = "a";
        category = "int";
      }
    ];
    value = {
      a = 1;
      b = 2;
      hidden = poison.poison;
    };
  };
  selectedMismatch = boundary.observeFields {
    name = "shallow";
    fields = [
      {
        name = "b";
        category = "int";
      }
      {
        name = "a";
        category = "int";
      }
    ];
    value = {
      a = poison.poison;
      b = "wrong";
    };
  };
  selectedPoison = boundary.observeFields {
    name = "shallow";
    fields = [ poison.poison ];
    value = { };
  };
  selectedExactValidation = boundary.observeFields {
    name = "shallow";
    fields = generatedSelections 8;
    value = poison.poison;
  };
  selectedOverValidation = boundary.observeFields {
    name = "shallow";
    fields = generatedSelections 8 ++ [ poison.poison ];
    value = poison.poison;
  };
  selectedStandardStress = boundary.observeFields {
    name = "standard";
    fields = generatedSelections 127;
    value = generatedValues 127;
  };

  deepSelected = boundary.observeDeep {
    name = "shallow";
    plan = attrsPlan [ (fieldPlan "selected" (categoryPlan "int")) ];
    value = poison.poisonedAttrs;
  };
  deepSortedMismatch = boundary.observeDeep {
    name = "shallow";
    plan = attrsPlan [
      (fieldPlan "b" (categoryPlan "int"))
      (fieldPlan "a" (categoryPlan "int"))
    ];
    value = {
      a = "wrong";
      b = poison.poison;
    };
  };
  deepRecursiveList = boundary.observeDeep {
    name = "shallow";
    plan = listPlan opaquePlan;
    value = poison.recursiveList;
  };
  deepRecursiveAttrs = boundary.observeDeep {
    name = "shallow";
    plan = attrsPlan [ (fieldPlan "self" opaquePlan) ];
    value = poison.recursiveAttrs;
  };
  exactDepth = boundary.observeDeep {
    name = "shallow";
    plan = nestPlan 4;
    value = nestValue 4;
  };
  overDepth = boundary.observeDeep {
    name = "shallow";
    plan = nestPlan 5;
    value = nestValue 5;
  };

  exactPlanNodes = boundary.validatePlan (
    attrsPlan (generatedFields 126 ++ [ (fieldPlan "z" (listPlan (categoryPlan "int"))) ])
  );
  overPlanNodes = boundary.validatePlan (
    attrsPlan (generatedFields 127 ++ [ (fieldPlan "z" poison.poison) ])
  );
  exactPlanDepth = boundary.validatePlan (nestPlan 64);
  overPlanDepth = boundary.validatePlan (nestPlanTail 65 poison.poison);
  poisonedPlan = boundary.validatePlan poison.poison;
  nestedAttrPlan = nestAttrPlan 40;
  validatedNestedAttrPlan = boundary.validatePlan nestedAttrPlan;
  observedNestedAttrPlan = boundary.observeDeep {
    name = "standard";
    plan = nestedAttrPlan;
    value = nestAttrValue 40;
  };

  exactStandardNodes = boundary.observeDeep {
    name = "standard";
    plan = listPlan opaquePlan;
    value = builtins.genList (_index: poison.poison) 255;
  };
  overStandardNodes = boundary.observeDeep {
    name = "standard";
    plan = listPlan opaquePlan;
    value = builtins.genList (_index: poison.poison) 256;
  };
  exactStandardDepth = boundary.observeDeep {
    name = "standard";
    plan = nestPlan 32;
    value = nestValue 32;
  };
  overStandardDepth = boundary.observeDeep {
    name = "standard";
    plan = nestPlan 33;
    value = nestValueTail 33 poison.poison;
  };

  callbackThrow = boundary.invoke {
    callback = poison.throwingCallback;
    argument = null;
    expected = "int";
  };
  callbackMalformed = boundary.invoke {
    callback = poison.malformedCallback;
    argument = null;
    expected = "int";
  };
  poisonedPolicy = boundary.validatePolicy poison.poison;
  poisonedExpected = boundary.invoke {
    callback = poison.malformedCallback;
    argument = null;
    expected = poison.poison;
  };

  forged = {
    kind = "success";
    operation = "forged";
    path = [ ];
    policy = "outer";
    category = "int";
    payload = poison.poison;
  };
  forbiddenExports = [
    "core"
    "trusted"
    "checked"
    "proof"
    "type"
    "term"
    "semanticDispatch"
    "semantic-dispatch"
  ];

  cases = [
    {
      name = "public host categories map exactly";
      pass = outerCategoriesPass;
    }
    {
      name = "opaque observation leaves the value unobserved";
      pass = opaquePoison.kind == "success" && opaquePoison.category == null;
    }
    {
      name = "outer observation classifies without forcing descendants";
      pass = outerLazyAttrs.kind == "success" && outerLazyAttrs.category == "attrs";
    }
    {
      name = "inactive branches remain inactive";
      pass = outerInactive.kind == "success" && outerInactive.category == "int";
    }
    {
      name = "outer poison is a named host failure";
      pass =
        outerPoison.kind == "host-failure" && outerPoison.guardedOperation == "host-type-classification";
    }
    {
      name = "derivations remain attrs";
      pass = outerDerivation.kind == "success" && outerDerivation.category == "attrs";
    }
    {
      name = "context strings remain strings";
      pass = outerContextString.kind == "success" && outerContextString.category == "string";
    }
    {
      name = "ordinary function observation does not invoke callbacks";
      pass = outerDivergentCallback.kind == "success" && outerDivergentCallback.category == "function";
    }
    {
      name = "list spine leaves elements lazy";
      pass = listSpine.kind == "success" && listSpine.payload.size == 2;
    }
    {
      name = "attr spine leaves values lazy";
      pass = attrsSpine.kind == "success" && attrsSpine.payload.size == 2;
    }
    {
      name = "exact node budget succeeds";
      pass = exactSpine.kind == "success" && exactSpine.payload.consumed == 8;
    }
    {
      name = "one over node budget refuses before forcing";
      pass =
        overSpine.kind == "resource-exhaustion"
        && overSpine.dimension == "nodes"
        && overSpine.limit == 8
        && overSpine.consumed == 8
        && overSpine.path == [ "index:7" ];
    }
    {
      name = "large spine stops at the first refused entry";
      pass =
        largeSpine.kind == "resource-exhaustion"
        && largeSpine.consumed == 1
        && largeSpine.path == [ "index:0" ];
    }
    {
      name = "poisoned budget name is a host failure";
      pass =
        poisonedBudgetName.kind == "host-failure"
        && poisonedBudgetName.guardedOperation == "budget-name-validation";
    }
    {
      name = "public observation budgets are frozen";
      pass =
        builtins.attrNames boundary.budgets == [
          "shallow"
          "single"
          "standard"
        ];
    }
    {
      name = "spine rejects the internal plan budget";
      pass = planSpineBudget.kind == "boundary-mismatch" && planSpineBudget.observed == "plan";
    }
    {
      name = "selected fields reject the internal plan budget";
      pass = planFieldBudget.kind == "boundary-mismatch" && planFieldBudget.observed == "plan";
    }
    {
      name = "typed deep rejects the internal plan budget";
      pass = planDeepBudget.kind == "boundary-mismatch" && planDeepBudget.observed == "plan";
    }
    {
      name = "selected fields use declaration order";
      pass =
        selectedOrder.kind == "success"
        &&
          map (entry: entry.name) selectedOrder.payload.observations == [
            "b"
            "a"
          ];
    }
    {
      name = "selected fields leave later fields untouched after mismatch";
      pass =
        selectedMismatch.kind == "boundary-mismatch"
        && selectedMismatch.path == [ "field:b" ]
        && selectedMismatch.expected == "int"
        && selectedMismatch.observed == "string";
    }
    {
      name = "poisoned selected-field control is a host failure";
      pass =
        selectedPoison.kind == "host-failure"
        && selectedPoison.guardedOperation == "selected-field-specification-validation";
    }
    {
      name = "exact selected-field validation boundary is admitted";
      pass =
        selectedExactValidation.kind == "resource-exhaustion"
        && selectedExactValidation.path == [ ]
        && selectedExactValidation.consumed == 8;
    }
    {
      name = "one over selected-field validation is refused untouched";
      pass =
        selectedOverValidation.kind == "resource-exhaustion"
        && selectedOverValidation.path == [ "selection:8" ]
        && selectedOverValidation.consumed == 8;
    }
    {
      name = "standard selected-field accumulation stays ordered";
      pass =
        selectedStandardStress.kind == "success"
        && selectedStandardStress.payload.consumed == 255
        && builtins.length selectedStandardStress.payload.observations == 127
        && (builtins.head selectedStandardStress.payload.observations).name == "f0"
        && (builtins.elemAt selectedStandardStress.payload.observations 126).name == "f126";
    }
    {
      name = "typed deep follows only the validated plan";
      pass = deepSelected.kind == "success" && deepSelected.payload.consumed == 2;
    }
    {
      name = "typed deep attr fields use lexical order";
      pass = deepSortedMismatch.kind == "boundary-mismatch" && deepSortedMismatch.path == [ "field:a" ];
    }
    {
      name = "recursive list descendants can remain opaque";
      pass = deepRecursiveList.kind == "success" && deepRecursiveList.payload.consumed == 2;
    }
    {
      name = "recursive attr descendants can remain opaque";
      pass = deepRecursiveAttrs.kind == "success" && deepRecursiveAttrs.payload.consumed == 2;
    }
    {
      name = "root depth zero admits depth four";
      pass = exactDepth.kind == "success" && exactDepth.payload.consumed == 5;
    }
    {
      name = "depth five is refused without charging";
      pass =
        overDepth.kind == "resource-exhaustion"
        && overDepth.dimension == "depth"
        && overDepth.limit == 4
        && overDepth.consumed == 5;
    }
    {
      name = "exact plan node boundary succeeds";
      pass = exactPlanNodes.kind == "success";
    }
    {
      name = "one over plan node boundary exhausts before poison";
      pass =
        overPlanNodes.kind == "resource-exhaustion"
        && overPlanNodes.dimension == "nodes"
        && overPlanNodes.limit == 256
        && overPlanNodes.consumed == 256
        && overPlanNodes.path == [ "field:z" ];
    }
    {
      name = "exact plan depth boundary succeeds";
      pass = exactPlanDepth.kind == "success";
    }
    {
      name = "one over plan depth boundary exhausts before poison";
      pass =
        overPlanDepth.kind == "resource-exhaustion"
        && overPlanDepth.dimension == "depth"
        && overPlanDepth.limit == 64
        && overPlanDepth.consumed == 65;
    }
    {
      name = "nested attr plan uses the internal plan budget";
      pass = validatedNestedAttrPlan.kind == "success";
    }
    {
      name = "nested attr observation keeps the public depth limit";
      pass =
        observedNestedAttrPlan.kind == "resource-exhaustion"
        && observedNestedAttrPlan.budget == "standard"
        && observedNestedAttrPlan.dimension == "depth"
        && observedNestedAttrPlan.limit == 32;
    }
    {
      name = "standard machine node boundary succeeds";
      pass = exactStandardNodes.kind == "success" && exactStandardNodes.payload.consumed == 256;
    }
    {
      name = "standard machine one over node boundary exhausts";
      pass =
        overStandardNodes.kind == "resource-exhaustion"
        && overStandardNodes.dimension == "nodes"
        && overStandardNodes.consumed == 256
        && overStandardNodes.path == [ "index:255" ];
    }
    {
      name = "standard machine depth 32 succeeds";
      pass = exactStandardDepth.kind == "success" && exactStandardDepth.payload.consumed == 33;
    }
    {
      name = "standard machine depth 33 refuses poison";
      pass =
        overStandardDepth.kind == "resource-exhaustion"
        && overStandardDepth.dimension == "depth"
        && overStandardDepth.limit == 32
        && overStandardDepth.consumed == 33;
    }
    {
      name = "callback throw is a named host failure";
      pass =
        callbackThrow.kind == "host-failure" && callbackThrow.guardedOperation == "callback-application";
    }
    {
      name = "callback malformed return is a mismatch";
      pass =
        callbackMalformed.kind == "boundary-mismatch"
        && callbackMalformed.expected == "int"
        && callbackMalformed.observed == "string";
    }
    {
      name = "poisoned policy is a host failure";
      pass =
        poisonedPolicy.kind == "host-failure"
        && poisonedPolicy.guardedOperation == "validate-policy-control-validation";
    }
    {
      name = "poisoned callback expectation is a host failure";
      pass =
        poisonedExpected.kind == "host-failure"
        && poisonedExpected.guardedOperation == "validate-category-control-validation";
    }
    {
      name = "poisoned plan node is a host failure";
      pass =
        poisonedPlan.kind == "host-failure"
        && poisonedPlan.guardedOperation == "observation-plan-node-validation";
    }
    {
      name = "unknown public policy is a mismatch";
      pass = (boundary.validatePolicy "unknown").kind == "boundary-mismatch";
    }
    {
      name = "malformed public plan is a mismatch";
      pass = (boundary.validatePlan { kind = "future"; }).kind == "boundary-mismatch";
    }
    {
      name = "result recognition accepts forgeable exact shapes";
      pass = result.isResult forged;
    }
    {
      name = "result recognition leaves payloads lazy";
      pass = result.isResult (boundary.observeOpaque poison.poison);
    }
    {
      name = "result recognition rejects extra control fields";
      pass = !(result.isResult (forged // { extra = true; }));
    }
    {
      name = "result recognition rejects wrong control classes";
      pass = !(result.isResult (forged // { operation = poison.poison; }));
    }
    {
      name = "result recognition returns ordinary data";
      pass = builtins.isBool (result.isResult forged) && !(forged ? dispatch);
    }
    {
      name = "internal bug codes are stable";
      pass =
        result.codes == {
          unknownPolicyDispatch = "AXIOM-HOST-001";
          unknownPlanDispatch = "AXIOM-HOST-002";
          budgetUnderflow = "AXIOM-HOST-003";
          impossibleTraversal = "AXIOM-HOST-004";
          unknownHostCategory = "AXIOM-HOST-005";
        };
    }
    {
      name = "new line export surface is frozen";
      pass =
        builtins.attrNames language == [
          "boundary"
          "generation"
          "syntax"
        ]
        &&
          builtins.attrNames boundary == [
            "budgets"
            "categories"
            "invoke"
            "observeDeep"
            "observeFields"
            "observeOpaque"
            "observeOuter"
            "observeSpine"
            "policies"
            "result"
            "validatePlan"
            "validatePolicy"
          ];
    }
    {
      name = "new line exports no semantic authority";
      pass = builtins.all (
        name: !(builtins.hasAttr name language) && !(builtins.hasAttr name boundary)
      ) forbiddenExports;
    }
  ];

  failing = builtins.filter (case: !case.pass) cases;
  ok =
    if failing == [ ] then
      true
    else
      throw "axiom host boundary tests FAILED: ${
        builtins.concatStringsSep ", " (map (case: case.name) failing)
      }";
in
{
  inherit cases ok;
}
