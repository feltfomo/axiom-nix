let
  structuralRow = id: operations: owner: forcing: resources: permanentTestCaseIds: {
    inherit
      id
      operations
      owner
      forcing
      resources
      permanentTestCaseIds
      ;
  };
  levelRow = id: instanceMembers: owner: forcing: resources: permanentTestCaseIds: {
    inherit
      id
      instanceMembers
      owner
      forcing
      resources
      permanentTestCaseIds
      ;
  };
  familyRow = values: values;
  owners = {
    formation = "language/kernel/checking.nix";
    introduction = "language/kernel/checking.nix";
    elimination = "language/kernel/checking.nix";
    computation = "language/evaluation";
    equality = "language/kernel/conversion.nix";
    readback = "language/kernel/readback.nix";
  };
  family =
    constructors: formation: introduction: elimination: computation: equality: etaStatus: binderOrder: forcing: resources: permanentTestCaseIds: rejectedLaws:
    familyRow {
      inherit
        constructors
        formation
        introduction
        elimination
        computation
        equality
        etaStatus
        binderOrder
        forcing
        resources
        permanentTestCaseIds
        rejectedLaws
        ;
      semanticOwners = owners;
    };
in
{
  structural = {
    context =
      structuralRow "S1-CONTEXT" [ ] "language/kernel" "context observation stays kernel-owned"
        "kernel context budget"
        [ "kernel.contextValid" ];
    admission =
      structuralRow "S1-ADMISSION" [ "admitted" "validate" ] "language/core"
        "refusal precedes protected inspection"
        "shared term and level input"
        [
          "core-syntax.completeConstructorOperationMatrix"
          "core-syntax.nodePoisonRefused"
          "core-syntax.depthPoisonRefused"
        ];
    renameIdentity =
      structuralRow "S1-RENAME-ID" [ "weaken" "rename" ] "language/core/operations.nix"
        "variables follow structural admission"
        "core syntax input"
        [
          "core-syntax.generatedStructuralLaws"
          "core-syntax.weakeningExact"
        ];
    renameComposition =
      structuralRow "S1-RENAME-COMPOSE" [ "rename" ] "language/core/operations.nix"
        "variable actions follow declaration order"
        "core syntax input"
        [ "core-syntax.collisionRenamingExact" ];
    substitutionIdentity =
      structuralRow "S1-SUBST-ID" [ "substitute" ] "language/core/operations.nix"
        "replacements are admitted before use"
        "source and replacement input"
        [ "core-syntax.completeConstructorOperationMatrix" ];
    substitutionComposition =
      structuralRow "S1-SUBST-COMPOSE" [ "substitute" ] "language/core/operations.nix"
        "replacement metadata follows occurrences"
        "core syntax input"
        [
          "core-syntax.substitutionComposition"
          "core-syntax.substitutionBeneathBinders"
          "core-syntax.nestedCaptureExact"
        ];
    openClose =
      structuralRow "S1-OPEN-CLOSE" [ "open" "close" "closeBinderBody" "openBinderBody" ]
        "language/core/operations.nix"
        "binder metadata follows body paths"
        "core syntax input"
        [
          "core-syntax.openThenClose"
          "core-syntax.closeThenOpen"
          "core-syntax.openingReplacementMetadata"
        ];
    equality =
      structuralRow "S1-STRUCTURAL-EQUALITY" [ "structurallyEqual" ] "language/core/operations.nix"
        "both operands are admitted first"
        "two core syntax inputs"
        [ "core-syntax.completeConstructorOperationMatrix" ];
  };
  levels = {
    zero = levelRow "S2-ZERO" [
      "zero"
    ] "language/core/levels.nix" "the constructor is representation-owned" "none" [ "levels.zero" ];
    successor =
      levelRow "S2-SUCCESSOR" [ "successor" ] "language/core/levels.nix" "input is normalized first"
        "independent input and output"
        [
          "levels.successorMaximum"
          "levels.universeSuccessor"
        ];
    join =
      levelRow "S2-JOIN" [ "join" ] "language/core/levels.nix" "both inputs are hostile-normalized"
        "independent inputs"
        [
          "levels.associativity"
          "levels.commutativity"
          "levels.idempotence"
          "levels.zero"
        ];
    height =
      levelRow "S2-HEIGHT" [ "height" ] "language/core/levels.nix"
        "outer and control observation is guarded"
        "shared enclosing input"
        [
          "levels.exactCombinedInputNodes"
          "levels.exactCombinedInputDepth"
        ];
    canonical =
      levelRow "S2-CANONICAL" [ "canonicalize" ] "language/core/levels.nix"
        "rebuilding follows normalization"
        "independent output"
        [
          "levels.normalizationStable"
          "levels.outputExact"
          "levels.outputOneOver"
        ];
    equality =
      levelRow "S2-EQUALITY" [ "equal" "requireExact" ] "language/core/levels.nix"
        "raw hostile values are never compared"
        "two independent inputs"
        [
          "levels.normalizationStable"
          "levels.noCumulativity"
        ];
  };
  families = {
    judgment =
      family [ "variable" "annotation" ] [ "S1-CONTEXT" ] [ ] [ ] [ ] [ "S1-STRUCTURAL-EQUALITY" ] null
        {
          annotation = [
            "subject"
            "annotation"
          ];
        } [ "declaration order" ] [ "core syntax" ]
        [ "core-syntax.completeConstructorOperationMatrix" ]
        [ ];
    universe =
      family [ "universe" ] [ "S3-UNIVERSE-FORMATION" ] [ ] [ ] [ "S2-CANONICAL" ] [ "S2-EQUALITY" ] null
        { } [ "shared level input" ] [ "level input" "level output" ]
        [ "levels.universeSuccessor" "levels.noCumulativity" "kernel.formation" ]
        [ "cumulativity" "self membership" ];
    pi =
      family [ "pi" "lambda" "application" ] [ "S3-PI-FORMATION" ]
        [ "S3-PI-LAMBDA" ]
        [ "S3-PI-APPLICATION" ] [ "S3-PI-BETA" ] [ "S3-PI-CONGRUENCE" ]
        "extensional"
        {
          pi = [
            "domain"
            "codomain"
          ];
          lambda = [ "body" ];
        } [ "inactive arguments stay unforced" ] [ "checking" "conversion" "evaluation" ]
        [ "kernel.formation" "kernel.piEta" "core-syntax.completeConstructorOperationMatrix" ]
        [ "function extensionality" ];
    sigma =
      family [ "sigma" "pair" "first-projection" "second-projection" ] [ "S3-SIGMA-FORMATION" ]
        [ "S3-SIGMA-PAIR" ]
        [ "S3-SIGMA-FIRST" "S3-SIGMA-SECOND" ] [ "S3-SIGMA-PROJECTIONS" ] [ "S3-SIGMA-CONGRUENCE" ]
        "surjective-pair"
        {
          sigma = [
            "domain"
            "codomain"
          ];
        } [ "second components follow first components" ] [ "checking" "conversion" "evaluation" ]
        [ "kernel.sigmaEta" "core-syntax.completeConstructorOperationMatrix" ]
        [ ];
    sum =
      family [ "sum-type" "left-injection" "right-injection" "sum-elimination" ] [ "S3-SUM-FORMATION" ]
        [ "S3-SUM-LEFT" "S3-SUM-RIGHT" ]
        [ "S3-SUM-CASE" ] [ "S3-SUM-LEFT-BETA" "S3-SUM-RIGHT-BETA" ] [ "S3-SUM-CONGRUENCE" ]
        "none"
        {
          case = [
            "scrutinee"
            "motive"
            "leftBranch"
            "rightBranch"
          ];
        } [ "inactive branches stay unforced" ] [ "checking" "conversion" "evaluation" ]
        [ "kernel.rejectedEtaControls" "core-syntax.completeConstructorOperationMatrix" ]
        [ "sum eta" ];
    unit =
      family [ "unit-type" "unit" "unit-elimination" ] [ "S3-UNIT-FORMATION" ]
        [ "S3-UNIT-INTRODUCTION" ]
        [ "S3-UNIT-ELIMINATION" ] [ "S3-UNIT-BETA" ] [ "S3-UNIT-UNIQUENESS" ]
        "typed-uniqueness"
        {
          elimination = [
            "scrutinee"
            "motive"
            "case"
          ];
        } [ "uniqueness is typed" ] [ "checking" "conversion" "evaluation" ]
        [ "kernel.unitUniqueness" "kernel.canonicityUnit" ]
        [ ];
    empty =
      family [ "empty-type" "empty-elimination" ] [ "S3-EMPTY-FORMATION" ] [ ] [ "S3-EMPTY-ELIMINATION" ]
        [ ]
        [ "S3-EMPTY-CONGRUENCE" ]
        "none"
        {
          elimination = [
            "scrutinee"
            "motive"
          ];
        } [ "the motive stays inactive" ] [ "checking" "conversion" "evaluation" ]
        [ "kernel.rejectedEtaControls" "core-syntax.completeConstructorOperationMatrix" ]
        [ "empty introduction" "empty eta" ];
    identity =
      family [ "identity-type" "refl" "identity-elimination" ] [ "S3-ID-FORMATION" ]
        [ "S3-ID-REFL" ]
        [ "S3-ID-J" ] [ "S3-ID-J-REFL" ] [ "S3-ID-CONGRUENCE" ]
        "none"
        {
          motive = [
            "source"
            "target"
            "evidence"
          ];
          reflBranch = [ "witness" ];
        } [ "general motive binder order" ] [ "checking" "conversion" "evaluation" ]
        [ "kernel.rejectedEtaControls" "core-syntax.completeConstructorOperationMatrix" ]
        [ "based J" "identity eta" "equality reflection" "UIP" "proof irrelevance" "postulates" ];
  };
}
