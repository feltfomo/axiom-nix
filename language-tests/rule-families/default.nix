{ core }:
let
  inherit (core) representation operations;
  r = representation;
  manifests = core.ruleFamilies;
  required = [
    "algorithms"
    "computation"
    "diagnostics"
    "elimination"
    "equality"
    "etaStatus"
    "formation"
    "introduction"
    "laws"
    "semantics"
    "syntax"
  ];
  families = [
    "empty"
    "identity"
    "pi"
    "sigma"
    "sum"
    "unit"
    "universe"
  ];
  sharedSchema = builtins.sort builtins.lessThan required;
  exactSchema =
    name:
    builtins.attrNames manifests.${name} == (
      if name == "identity" then
        builtins.sort builtins.lessThan (
          required
          ++ [
            "binderOrder"
            "excluded"
            "rejectedSyntax"
          ]
        )
      else
        sharedSchema
    );
  nonemptyText = value: builtins.isString value && value != "";
  listOfText = value: builtins.isList value && builtins.all nonemptyText value;
  typedRow =
    name:
    let
      row = manifests.${name};
    in
    listOfText row.syntax
    && nonemptyText row.formation
    && listOfText row.introduction
    && listOfText row.elimination
    && listOfText row.computation
    && listOfText row.equality
    && nonemptyText row.etaStatus
    && listOfText row.semantics
    && nonemptyText row.diagnostics
    && listOfText row.laws
    && builtins.isAttrs row.algorithms
    &&
      row.algorithms.now == [
        "syntax"
        "scope"
        "levels"
        "evaluation"
        "law evidence"
      ]
    &&
      row.algorithms.later == [
        "checking"
        "conversion"
        "quotation"
        "readback"
      ];
  admitted =
    scope: root:
    let
      value = operations.admitted (r.envelope scope root [ ]);
    in
    value.ok;
  v0 = r.variable 0;
  constructors = [
    (r.lambda (r.variable 1))
    (r.application v0 v0)
    (r.annotation v0 v0)
    (r.universe r.levelZero)
    (r.pi v0 (r.variable 1))
    (r.sigma v0 (r.variable 1))
    (r.sumType v0 v0)
    r.unitType
    r.unit
    r.emptyType
    (r.pair v0 v0)
    (r.firstProjection v0)
    (r.secondProjection v0)
    (r.leftInjection v0)
    (r.rightInjection v0)
    (r.sumElimination v0 (r.variable 1) (r.variable 1) (r.variable 1))
    (r.unitElimination v0 (r.variable 1) v0)
    (r.emptyElimination v0 (r.variable 1))
    (r.identityType v0 v0 v0)
    (r.refl v0)
    (r.identityElimination v0 (r.variable 3) (r.variable 1))
  ];
  original = r.envelope 3 (r.identityElimination (r.variable 0) (r.application (r.variable 3) (
    r.application (r.variable 4) (r.variable 5)
  )) (r.variable 3)) [ ];
  closed = operations.closeBinderBody {
    envelope = original;
    sourceLevels = [
      0
      1
      2
    ];
  };
  replacements = map (level: r.envelope 3 (r.variable level) [ ]) [
    0
    1
    2
  ];
  opened =
    if closed.ok then
      operations.openBinderBody {
        envelope = closed.value;
        outerScope = 3;
        inherit replacements;
      }
    else
      closed;
  swapped =
    if closed.ok then
      operations.openBinderBody {
        envelope = closed.value;
        outerScope = 3;
        replacements = [
          (builtins.elemAt replacements 1)
          (builtins.elemAt replacements 0)
          (builtins.elemAt replacements 2)
        ];
      }
    else
      closed;
  zeroClosed = operations.closeBinderBody {
    envelope = r.envelope 1 v0 [ ];
    sourceLevels = [ ];
  };
  oneClosed = operations.closeBinderBody {
    envelope = r.envelope 1 v0 [ ];
    sourceLevels = [ 0 ];
  };
  duplicate = operations.closeBinderBody {
    envelope = r.envelope 2 (r.application (r.variable 0) (r.variable 1)) [ ];
    sourceLevels = [
      0
      0
    ];
  };
  cases = {
    inventory = builtins.attrNames manifests == families;
    schemas = builtins.all exactSchema families && builtins.all typedRow families;
    placeholdersOnly = builtins.all (
      name:
      manifests.${name}.algorithms.later == [
        "checking"
        "conversion"
        "quotation"
        "readback"
      ]
    ) families;
    generalJ =
      manifests.identity.binderOrder.motive == [
        "source"
        "target"
        "evidence"
      ]
      && manifests.identity.binderOrder.reflBranch == [ "witness" ]
      && manifests.identity.rejectedSyntax == "based J"
      &&
        manifests.identity.excluded == [
          "equality reflection"
          "function extensionality"
          "UIP"
          "proof irrelevance"
          "postulates"
        ];
    explicitEmptyRules =
      manifests.universe.introduction == [ ]
      && manifests.universe.elimination == [ ]
      && manifests.empty.introduction == [ ]
      && manifests.empty.computation == [ ];
    primitiveInventorySynchronized =
      builtins.sort builtins.lessThan (
        builtins.concatLists (map (name: manifests.${name}.syntax) families)
      ) == builtins.sort builtins.lessThan [
        "universe"
        "pi"
        "lambda"
        "application"
        "sigma"
        "pair"
        "first-projection"
        "second-projection"
        "sum-type"
        "left-injection"
        "right-injection"
        "sum-elimination"
        "unit-type"
        "unit"
        "unit-elimination"
        "empty-type"
        "empty-elimination"
        "identity-type"
        "refl"
        "identity-elimination"
      ];
    manifestIndependent = !(manifests ? evaluate) && !(manifests ? traverse) && !(manifests ? check);
    executableInventory = builtins.all (admitted 1) constructors;
    generalJRoundTrip = closed.ok && opened.ok && operations.structurallyEqual original opened.value;
    generalJOrderMatters = swapped.ok && !operations.structurallyEqual original swapped.value;
    binderCounts =
      zeroClosed.ok && zeroClosed.value.scope == 1 && oneClosed.ok && oneClosed.value.scope == 2;
    duplicateSourcesRejected = !duplicate.ok;
  };
  failing = builtins.filter (name: !cases.${name}) (builtins.attrNames cases);
in
{
  inherit cases;
  ok =
    if failing == [ ] then
      true
    else
      throw "axiom rule family tests FAILED: ${builtins.concatStringsSep ", " failing}";
}
