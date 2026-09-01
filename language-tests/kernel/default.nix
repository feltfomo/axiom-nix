{ language }:
let
  core = import ../../language/core;
  kernel = import ../../language/kernel { inherit core; };
  evaluation = import ../../language/evaluation { inherit core; };
  kernelRepresentation = import ../../language/kernel/representation.nix { inherit evaluation; };
  kernelResult = import ../../language/kernel/result.nix {
    representation = kernelRepresentation;
    inherit core;
  };
  r = core.representation;
  sem = evaluation.representation;
  checked =
    terms:
    kernel.checkContext {
      entries = builtins.genList (index: r.envelope index (builtins.elemAt terms index) [ ]) (
        builtins.length terms
      );
    };
  unitContextResult = checked [ r.unitType ];
  unitContext = unitContextResult.context;
  unitVariable = kernel.infer {
    contextValue = unitContext;
    envelope = r.envelope 1 (r.variable 0) [ ];
  };
  unitValue = kernel.check {
    contextValue = unitContext;
    envelope = r.envelope 1 r.unit [ ];
    expected = sem.unitType;
  };
  unitConversion = kernel.convertTerms {
    contextValue = unitContext;
    type = sem.unitType;
    left = unitVariable.value;
    right = unitValue.value;
  };
  unitOracle = kernel.oracle {
    contextValue = unitContext;
    type = sem.unitType;
    left = unitVariable.value;
    right = unitValue.value;
  };
  piSyntax = r.pi r.unitType r.unitType;
  piContextResult = checked [ piSyntax ];
  piContext = piContextResult.context;
  piVariable = kernel.infer {
    contextValue = piContext;
    envelope = r.envelope 1 (r.variable 0) [ ];
  };
  piEta = kernel.check {
    contextValue = piContext;
    envelope = r.envelope 1 (r.lambda (r.application (r.variable 0) (r.variable 1))) [ ];
    expected = piVariable.type;
  };
  piConversion = kernel.convertTerms {
    contextValue = piContext;
    inherit (piVariable) type;
    left = piVariable.value;
    right = piEta.value;
  };
  piOracle = kernel.oracle {
    contextValue = piContext;
    inherit (piVariable) type;
    left = piVariable.value;
    right = piEta.value;
  };
  sigmaSyntax = r.sigma r.unitType r.unitType;
  sigmaContextResult = checked [ sigmaSyntax ];
  sigmaContext = sigmaContextResult.context;
  sigmaVariable = kernel.infer {
    contextValue = sigmaContext;
    envelope = r.envelope 1 (r.variable 0) [ ];
  };
  sigmaEta = kernel.check {
    contextValue = sigmaContext;
    envelope = r.envelope 1 (r.pair (r.firstProjection (r.variable 0)) (
      r.secondProjection (r.variable 0)
    )) [ ];
    expected = sigmaVariable.type;
  };
  sigmaConversion = kernel.convertTerms {
    contextValue = sigmaContext;
    inherit (sigmaVariable) type;
    left = sigmaVariable.value;
    right = sigmaEta.value;
  };
  sigmaOracle = kernel.oracle {
    contextValue = sigmaContext;
    inherit (sigmaVariable) type;
    left = sigmaVariable.value;
    right = sigmaEta.value;
  };
  universe = kernel.infer {
    contextValue = unitContext;
    envelope = r.envelope 1 (r.universe r.levelZero) [ ];
  };
  piFormation = kernel.form {
    contextValue = unitContext;
    envelope = r.envelope 1 piSyntax [ ];
  };
  negativeLambdaInference = kernel.infer {
    contextValue = unitContext;
    envelope = r.envelope 1 (r.lambda (r.variable 1)) [ ];
  };
  staleType = sem.unitType // {
    generation = "axiom-evaluation-1";
  };
  stale = kernel.check {
    contextValue = unitContext;
    envelope = r.envelope 1 r.unit [ ];
    expected = staleType;
  };
  emptyContext = (kernel.checkContext { entries = [ ]; }).context;
  checkingExact = kernel.infer {
    contextValue = emptyContext;
    envelope = r.envelope 0 r.unitType [ ];
    limits = {
      checking = 1;
    };
  };
  checkingOneOver = kernel.infer {
    contextValue = emptyContext;
    envelope = r.envelope 0 r.unitType [ ];
    limits = {
      checking = 0;
    };
  };
  contextExact = kernel.checkContext {
    entries = [ (r.envelope 0 r.unitType [ ]) ];
    limits = {
      context = 1;
    };
  };
  contextOneOver = kernel.checkContext {
    entries = [ (builtins.throw "context poison inspected") ];
    limits = {
      context = 0;
    };
  };
  binderContextExact = kernel.form {
    contextValue = emptyContext;
    envelope = r.envelope 0 piSyntax [ ];
    limits = {
      context = 1;
    };
  };
  binderContextOneOver = kernel.form {
    contextValue = emptyContext;
    envelope = r.envelope 0 piSyntax [ ];
    limits = {
      context = 0;
    };
  };
  conversionExact = kernel.convertTerms {
    contextValue = emptyContext;
    type = sem.unitType;
    left = sem.unit;
    right = sem.unit;
    limits = {
      conversion = 1;
      comparison = 1;
    };
  };
  conversionOneOver = kernel.convertTerms {
    contextValue = emptyContext;
    type = sem.unitType;
    left = sem.unit;
    right = sem.unit;
    limits = {
      conversion = 0;
      comparison = 0;
    };
  };
  readbackExact = kernel.quote {
    contextValue = emptyContext;
    type = sem.unitType;
    value = sem.unit;
    limits = {
      readback = 1;
      output = 1;
    };
  };
  readbackOneOver = kernel.quote {
    contextValue = emptyContext;
    type = sem.unitType;
    value = sem.unit;
    limits = {
      readback = 0;
      output = 0;
    };
  };
  universeQuotationExact = kernel.quoteType {
    contextValue = emptyContext;
    value = sem.universe core.levels.zero;
    limits = {
      readback = 1;
      output = 2;
    };
  };
  universeQuotationOneOver = kernel.quoteType {
    contextValue = emptyContext;
    value = sem.universe core.levels.zero;
    limits = {
      readback = 1;
      output = 1;
    };
  };
  oracleSharedExact = kernel.oracle {
    contextValue = emptyContext;
    type = sem.unitType;
    left = sem.unit;
    right = sem.unit;
    limits = {
      readback = 2;
      output = 2;
    };
  };
  oracleSharedOneOver = kernel.oracle {
    contextValue = emptyContext;
    type = sem.unitType;
    left = sem.unit;
    right = sem.unit;
    limits = {
      readback = 1;
      output = 2;
    };
  };
  goodResources = kernelRepresentation.resources { };
  trustedContext = kernelResult.checkedContext {
    context = emptyContext;
    resources = goodResources;
  };
  trustedFormation = kernelResult.formation {
    level = r.levelZero;
    type = sem.unitType;
    resources = goodResources;
  };
  trustedInference = kernelResult.inference {
    type = sem.unitType;
    value = sem.unit;
    resources = goodResources;
  };
  trustedChecking = kernelResult.checking {
    type = sem.unitType;
    value = sem.unit;
    resources = goodResources;
  };
  trustedTypeConversion = kernelResult.typeConversion { resources = goodResources; };
  trustedTermConversion = kernelResult.termConversion {
    type = sem.unitType;
    resources = goodResources;
    observations = {
      forced = 0;
    };
  };
  canonicalUnit = r.envelope 0 r.unit [ ];
  trustedReadback = kernelResult.readback {
    value = canonicalUnit;
    resources = goodResources;
  };
  trustedQuotation = kernelResult.quotation {
    value = canonicalUnit;
    resources = goodResources;
  };
  trustedOracle = kernelResult.oracle {
    left = canonicalUnit;
    right = canonicalUnit;
    resources = goodResources;
  };
  staleSemantic = sem.unitType // {
    generation = "axiom-evaluation-1";
  };
  hostileResults = [
    (
      trustedContext
      // {
        context = emptyContext // {
          entryCount = 1;
        };
      }
    )
    (trustedFormation // { extra = true; })
    (trustedInference // { type = staleSemantic; })
    (trustedChecking // { value = staleSemantic; })
    (
      trustedTypeConversion
      // {
        resources = goodResources // {
          extra = 0;
        };
      }
    )
    (
      trustedTermConversion
      // {
        observations = {
          forced = -1;
        };
      }
    )
    (
      trustedReadback
      // {
        value = canonicalUnit // {
          scope = -1;
        };
      }
    )
    (
      trustedReadback
      // {
        value = canonicalUnit // {
          root = {
            kind = "unit";
            extra = true;
          };
        };
      }
    )
    (
      trustedQuotation
      // {
        value = canonicalUnit // {
          generation = "axiom-core-syntax-1";
        };
      }
    )
    (
      trustedOracle
      // {
        right = canonicalUnit // {
          extra = true;
        };
      }
    )
  ];
  hostileValidators = [
    kernelResult.validators.checkedContext
    kernelResult.validators.formation
    kernelResult.validators.inference
    kernelResult.validators.checking
    kernelResult.validators.typeConversion
    kernelResult.validators.termConversion
    kernelResult.validators.readback
    kernelResult.validators.readback
    kernelResult.validators.quotation
    kernelResult.validators.oracle
  ];
  hostileRejected = builtins.all (
    index: !((builtins.elemAt hostileValidators index) (builtins.elemAt hostileResults index))
  ) (builtins.genList (x: x) (builtins.length hostileResults));
  conversionPairs = [
    {
      type = sem.unitType;
      left = unitVariable.value;
      right = unitValue.value;
    }
    {
      inherit (piVariable) type;
      left = piVariable.value;
      right = piEta.value;
    }
    {
      inherit (sigmaVariable) type;
      left = sigmaVariable.value;
      right = sigmaEta.value;
    }
  ];
  generatedAgreement = builtins.all (
    case:
    let
      optimized = kernel.convertTerms {
        contextValue =
          if case.type.kind == "unit-type" then
            unitContext
          else if case.type.kind == "pi" then
            piContext
          else
            sigmaContext;
        inherit (case) type left right;
      };
      reference = kernel.oracle {
        contextValue =
          if case.type.kind == "unit-type" then
            unitContext
          else if case.type.kind == "pi" then
            piContext
          else
            sigmaContext;
        inherit (case) type left right;
      };
    in
    optimized.ok == reference.ok
  ) conversionPairs;
  canonicalUnitReadback = kernel.quote {
    contextValue = emptyContext;
    type = sem.unitType;
    value = sem.unit;
  };
  emptyVariableContextResult = checked [ r.emptyType ];
  emptyVariableContext = emptyVariableContextResult.context;
  emptyVariable = kernel.infer {
    contextValue = emptyVariableContext;
    envelope = r.envelope 1 (r.variable 0) [ ];
  };
  openNeutralReadback = kernel.quote {
    contextValue = emptyVariableContext;
    type = sem.emptyType;
    inherit (emptyVariable) value;
  };
  sumContextResult = checked [ (r.sumType r.unitType r.unitType) ];
  sumContext = sumContextResult.context;
  sumVariable = kernel.infer {
    contextValue = sumContext;
    envelope = r.envelope 1 (r.variable 0) [ ];
  };
  sumEta = kernel.infer {
    contextValue = sumContext;
    envelope = r.envelope 1 (r.sumElimination (r.variable 0) (r.sumType r.unitType r.unitType)
      (r.leftInjection (r.variable 1))
      (r.rightInjection (r.variable 1))
    ) [ ];
  };
  sumEtaOptimized = kernel.convertTerms {
    contextValue = sumContext;
    inherit (sumVariable) type;
    left = sumVariable.value;
    right = sumEta.value;
  };
  sumEtaOracle = kernel.oracle {
    contextValue = sumContext;
    inherit (sumVariable) type;
    left = sumVariable.value;
    right = sumEta.value;
  };
  emptyEta = kernel.infer {
    contextValue = emptyVariableContext;
    envelope = r.envelope 1 (r.emptyElimination (r.variable 0) r.emptyType) [ ];
  };
  emptyEtaOptimized = kernel.convertTerms {
    contextValue = emptyVariableContext;
    inherit (emptyVariable) type;
    left = emptyVariable.value;
    right = emptyEta.value;
  };
  emptyEtaOracle = kernel.oracle {
    contextValue = emptyVariableContext;
    inherit (emptyVariable) type;
    left = emptyVariable.value;
    right = emptyEta.value;
  };
  identitySyntax = r.identityType r.unitType r.unit r.unit;
  identityContextResult = checked [ identitySyntax ];
  identityContext = identityContextResult.context;
  identityVariable = kernel.infer {
    contextValue = identityContext;
    envelope = r.envelope 1 (r.variable 0) [ ];
  };
  identityEta = kernel.infer {
    contextValue = identityContext;
    envelope = r.envelope 1 (r.identityElimination (r.variable 0) identitySyntax (r.refl r.unit)) [ ];
  };
  identityEtaOptimized = kernel.convertTerms {
    contextValue = identityContext;
    inherit (identityVariable) type;
    left = identityVariable.value;
    right = identityEta.value;
  };
  identityEtaOracle = kernel.oracle {
    contextValue = identityContext;
    inherit (identityVariable) type;
    left = identityVariable.value;
    right = identityEta.value;
  };
  unitElimination = kernel.infer {
    contextValue = unitContext;
    envelope = r.envelope 1 (r.unitElimination (r.variable 0) (r.universe r.levelZero) r.unitType) [ ];
  };
  unitEliminationReadback = kernel.quote {
    contextValue = unitContext;
    type = sem.universe core.levels.zero;
    inherit (unitElimination) value;
  };
  longSpineLength = 64;
  longPiSyntax = builtins.foldl' (body: _index: r.pi r.unitType body) r.unitType (
    builtins.genList (index: index) longSpineLength
  );
  longSpineContextResult = kernel.checkContext {
    entries = [ (r.envelope 0 longPiSyntax [ ]) ];
    limits = {
      checking = 4096;
      conversion = 4096;
      comparison = 4096;
      readback = 4096;
      context = 256;
      output = 256;
      depth = 64;
    };
  };
  longSpineContext = longSpineContextResult.context;
  longApplicationSyntax = builtins.foldl' (
    function: _index: r.application function r.unit
  ) (r.variable 0) (builtins.genList (index: index) longSpineLength);
  longSpineInference = kernel.infer {
    contextValue = longSpineContext;
    envelope = r.envelope 1 longApplicationSyntax [ ];
    limits = {
      checking = 4096;
      conversion = 4096;
      comparison = 4096;
      readback = 4096;
      context = 256;
      output = 256;
      depth = 64;
    };
  };
  longSpineReadback = kernel.quote {
    contextValue = longSpineContext;
    type = sem.unitType;
    inherit (longSpineInference) value;
    limits = {
      checking = 4096;
      conversion = 4096;
      comparison = 4096;
      readback = 4096;
      context = 256;
      output = 256;
      depth = 64;
    };
  };
  sumEtaControl = sumEta.ok && !sumEtaOptimized.ok && !sumEtaOracle.ok;
  emptyEtaControl = emptyEta.ok && !emptyEtaOptimized.ok && !emptyEtaOracle.ok;
  identityEtaControl = identityEta.ok && !identityEtaOptimized.ok && !identityEtaOracle.ok;
  poisonedSpineItem = {
    kind = builtins.throw "poisoned spine kind forced";
  };
  malformedSpineItem = {
    kind = "not-an-eliminator";
  };
  poisonedNeutral = (sem.neutral 0) // {
    spine = [ poisonedSpineItem ];
    spineCount = 1;
  };
  malformedNeutral = (sem.neutral 0) // {
    spine = [ malformedSpineItem ];
    spineCount = 1;
  };
  poisonedReadbackAttempt = builtins.tryEval (
    kernel.quote {
      contextValue = emptyVariableContext;
      type = sem.emptyType;
      value = poisonedNeutral;
    }
  );
  malformedReadbackAttempt = builtins.tryEval (
    kernel.quote {
      contextValue = emptyVariableContext;
      type = sem.emptyType;
      value = malformedNeutral;
    }
  );
  poisonedConversionAttempt = builtins.tryEval (
    kernel.convertTerms {
      contextValue = emptyVariableContext;
      type = sem.emptyType;
      left = poisonedNeutral;
      right = poisonedNeutral;
    }
  );
  malformedConversionAttempt = builtins.tryEval (
    kernel.convertTerms {
      contextValue = emptyVariableContext;
      type = sem.emptyType;
      left = malformedNeutral;
      right = malformedNeutral;
    }
  );
  hostileSpineRejected =
    builtins.all
      (
        attempted:
        attempted.success
        && !attempted.value.ok
        && attempted.value.kind == "internal-failure"
        && attempted.value.code == "AXIOM-KERNEL-004"
      )
      [
        poisonedReadbackAttempt
        malformedReadbackAttempt
        poisonedConversionAttempt
        malformedConversionAttempt
      ];
  malformedLimitCases = [
    (kernel.infer {
      contextValue = emptyContext;
      envelope = r.envelope 0 r.unitType [ ];
      limits = {
        unknown = 1;
      };
    })
    (kernel.infer {
      contextValue = emptyContext;
      envelope = r.envelope 0 r.unitType [ ];
      limits = {
        checking = -1;
      };
    })
    (kernel.infer {
      contextValue = emptyContext;
      envelope = r.envelope 0 r.unitType [ ];
      limits = {
        checking = 1.5;
      };
    })
    (kernel.infer {
      contextValue = emptyContext;
      envelope = r.envelope 0 r.unitType [ ];
      limits = [ ];
    })
    (kernel.infer {
      contextValue = emptyContext;
      envelope = r.envelope 0 r.unitType [ ];
      limits = builtins.throw "limits poison";
    })
  ];
  malformedLimitsRejected = builtins.all (
    value: !value.ok && value.kind == "internal-failure" && value.code == "AXIOM-KERNEL-011"
  ) malformedLimitCases;
  contains = needle: text: builtins.replaceStrings [ needle ] [ "" ] text != text;
  structuralSources = map builtins.readFile [
    ../../language/boundary/deep.nix
    ../../language/boundary/observe.nix
    ../../language/core/levels.nix
    ../../language/core/traversal.nix
    ../../language/evaluation/direct.nix
    ../../language/evaluation/machine.nix
    ../../language/kernel/checking.nix
    ../../language/kernel/conversion.nix
    ../../language/kernel/readback.nix
    ../../language/kernel/representation.nix
  ];
  conversionSource = builtins.readFile ../../language/kernel/conversion.nix;
  readbackSource = builtins.readFile ../../language/kernel/readback.nix;
  transitionSource = builtins.readFile ../../language/kernel/neutral-transition.nix;
  semanticSource = builtins.readFile ../../language/kernel/semantic.nix;
  budgetSource = builtins.readFile ../../language/kernel/budget.nix;
  representationSource = builtins.readFile ../../language/kernel/representation.nix;
  schemaSource = builtins.readFile ../../language/evaluation/schema.nix;
  checkingSource = builtins.readFile ../../language/kernel/checking.nix;
  transitionalOwnersPresent = builtins.all builtins.pathExists [
    ../../language/kernel/budget.nix
    ../../language/kernel/semantic.nix
    ../../language/kernel/neutral-transition.nix
  ];
  forbiddenPlanText =
    text:
    builtins.any (needle: contains needle text) [
      "makePlan"
      ".plan"
      "peerPlan"
      "handlersClosed"
      "neutralElimination"
    ];
  structuralReconciliation =
    builtins.all (text: !(contains "builtins.genericClosure" text)) structuralSources
    && !(forbiddenPlanText transitionSource)
    && !(forbiddenPlanText conversionSource)
    && !(forbiddenPlanText readbackSource)
    && contains "logismos.budget.make" budgetSource
    && contains "computation.bind" semanticSource
    && contains "computation.bind" transitionSource
    && contains "prepare =" transitionSource
    && contains "observePhase =" transitionSource
    && contains "advance =" transitionSource
    && contains "writtenSpine = reverse args.spine" transitionSource
    && contains "traversal.zipFold" transitionSource
    && !(contains "builtins.elemAt" transitionSource)
    && !(contains "builtins.tail" transitionSource)
    && !(contains "logismos.transition.run" transitionSource)
    && !(contains "stack.fromNewestFirst" transitionSource)
    && !(contains "semantic.runStateful" transitionSource)
    && !(contains "kernelState" transitionSource)
    && !(contains "args //" transitionSource)
    && contains "compareTypeProgram" conversionSource
    && contains "compareValueProgram" conversionSource
    && contains "inferProgram" checkingSource
    && contains "checkProgram" checkingSource
    && contains "formProgram" checkingSource
    && !(contains "runProgram =" checkingSource)
    && !(contains "kernelState" checkingSource)
    && !(contains "worklist" checkingSource)
    && !(contains "formAt =" checkingSource)
    && !(contains "inferAt =" checkingSource)
    && !(contains "checkAt =" checkingSource)
    && !(contains "runProgram =" conversionSource)
    && !(contains "neutralCompare =" conversionSource)
    && !(contains "compareType =" conversionSource)
    && !(contains "compareValue =" conversionSource)
    && contains "neutralTransition.replay" conversionSource
    && contains "neutralTransition.replay" readbackSource
    && contains "reflect =" readbackSource
    && contains "reify = quoteValue" readbackSource
    && contains "sem.extendNeutral d.value d.item" transitionSource
    && !(contains "extendNeutral" conversionSource)
    && !(contains "extendNeutral" readbackSource)
    && !(contains "boundedNewestFirst" representationSource)
    && !(contains "internal/worklist" representationSource)
    && !(contains "builtins.tail" transitionSource)
    && !(contains "builtins.tail" readbackSource)
    && !(contains "builtins.tail" conversionSource)
    && !(contains "  flow," checkingSource)
    && !(contains "semanticOps" checkingSource)
    && !(contains "resources." checkingSource)
    && !(contains "flow.andThen" conversionSource)
    && !(contains "flow.andThen" readbackSource)
    && contains "conversionRoles =" schemaSource
    && transitionalOwnersPresent;
  resourceFixture =
    {
      name,
      expected,
      actual,
    }:
    {
      inherit name expected actual;
      pass = actual == expected;
    };
  resourceEquivalenceMatrix = [
    (resourceFixture {
      name = "checking exact";
      expected = {
        ok = true;
        checking = 1;
      };
      actual = {
        inherit (checkingExact) ok;
        checking = checkingExact.resources.checking or null;
      };
    })
    (resourceFixture {
      name = "checking refusal";
      expected = {
        ok = false;
        kind = "resource-exhaustion";
        budget = "checking";
        limit = 0;
        consumed = 0;
      };
      actual = {
        inherit (checkingOneOver)
          ok
          kind
          budget
          limit
          consumed
          ;
      };
    })
    (resourceFixture {
      name = "context exact";
      expected = {
        ok = true;
        context = 1;
      };
      actual = {
        inherit (contextExact) ok;
        context = contextExact.resources.context or null;
      };
    })
    (resourceFixture {
      name = "context refusal before inspection";
      expected = {
        ok = false;
        kind = "resource-exhaustion";
        budget = "context";
        limit = 0;
        consumed = 0;
      };
      actual = {
        inherit (contextOneOver)
          ok
          kind
          budget
          limit
          consumed
          ;
      };
    })
    (resourceFixture {
      name = "binder context exact";
      expected = {
        ok = true;
        context = 1;
      };
      actual = {
        inherit (binderContextExact) ok;
        context = binderContextExact.resources.context or null;
      };
    })
    (resourceFixture {
      name = "binder context refusal";
      expected = {
        ok = false;
        kind = "resource-exhaustion";
        budget = "context";
      };
      actual = {
        inherit (binderContextOneOver)
          ok
          kind
          budget
          ;
      };
    })
    (resourceFixture {
      name = "conversion exact";
      expected = {
        ok = true;
        conversion = 1;
        comparison = 1;
      };
      actual = {
        inherit (conversionExact) ok;
        conversion = conversionExact.resources.conversion or null;
        comparison = conversionExact.resources.comparison or null;
      };
    })
    (resourceFixture {
      name = "conversion refusal";
      expected = {
        ok = false;
        kind = "resource-exhaustion";
        budget = "conversion";
      };
      actual = {
        inherit (conversionOneOver)
          ok
          kind
          budget
          ;
      };
    })
    (resourceFixture {
      name = "readback exact";
      expected = {
        ok = true;
        readback = 1;
        output = 1;
      };
      actual = {
        inherit (readbackExact) ok;
        readback = readbackExact.resources.readback or null;
        output = readbackExact.resources.output or null;
      };
    })
    (resourceFixture {
      name = "readback refusal";
      expected = {
        ok = false;
        kind = "resource-exhaustion";
        budget = "readback";
      };
      actual = {
        inherit (readbackOneOver)
          ok
          kind
          budget
          ;
      };
    })
    (resourceFixture {
      name = "level output exact";
      expected = {
        ok = true;
        readback = 1;
        output = 2;
      };
      actual = {
        inherit (universeQuotationExact) ok;
        readback = universeQuotationExact.resources.readback or null;
        output = universeQuotationExact.resources.output or null;
      };
    })
    (resourceFixture {
      name = "level output refusal";
      expected = {
        ok = false;
        kind = "resource-exhaustion";
        budget = "output";
      };
      actual = {
        inherit (universeQuotationOneOver)
          ok
          kind
          budget
          ;
      };
    })
    (resourceFixture {
      name = "oracle shared exact";
      expected = {
        ok = true;
        readback = 2;
        output = 2;
      };
      actual = {
        inherit (oracleSharedExact) ok;
        readback = oracleSharedExact.resources.readback or null;
        output = oracleSharedExact.resources.output or null;
      };
    })
    (resourceFixture {
      name = "oracle shared refusal";
      expected = {
        ok = false;
        kind = "resource-exhaustion";
        budget = "readback";
      };
      actual = {
        inherit (oracleSharedOneOver)
          ok
          kind
          budget
          ;
      };
    })
    (resourceFixture {
      name = "forced observations";
      expected = {
        ok = true;
        forced = 0;
      };
      actual = {
        inherit (unitConversion) ok;
        forced = unitConversion.observations.forced or null;
      };
    })
  ];
  resourceEquivalent =
    builtins.all (case: case.pass) resourceEquivalenceMatrix && hostileSpineRejected;
  evidence = {
    privateGeneration = kernel.generation == "axiom-kernel-1";
    malformedLimits = malformedLimitsRejected;
    hostileSpineValidation = hostileSpineRejected;
    structuralMechanisms = structuralReconciliation;
    resourceEquivalence = resourceEquivalent;
    evaluationSchemaAgreement =
      kernelRepresentation.evaluationGeneration == evaluation.representation.generation;
    publicFrozen =
      builtins.attrNames language == [
        "boundary"
        "generation"
        "syntax"
      ];
    contextValid = unitContextResult.ok && unitContext.depth == unitContext.environment.nextLevel;
    formation = universe.ok && piFormation.ok;
    introductions = unitValue.ok && piEta.ok && sigmaEta.ok;
    piEta = piConversion.ok && piOracle.ok;
    sigmaEta = sigmaConversion.ok && sigmaOracle.ok;
    unitUniqueness = unitConversion.ok && unitOracle.ok && unitConversion.observations.forced == 0;
    direction = !negativeLambdaInference.ok;
    staleRejected = !stale.ok;
    checkingResourceExact = checkingExact.ok && checkingExact.resources.checking == 1;
    checkingResourceOneOver =
      !checkingOneOver.ok
      && checkingOneOver.kind == "resource-exhaustion"
      && checkingOneOver.budget == "checking";
    contextResourceExact = contextExact.ok && contextExact.resources.context == 1;
    contextChargeBeforeInspection =
      !contextOneOver.ok
      && contextOneOver.kind == "resource-exhaustion"
      && contextOneOver.code == "AXIOM-KERNEL-001"
      && contextOneOver.budget == "context";
    binderContextResourceExact = binderContextExact.ok && binderContextExact.resources.context == 1;
    binderContextResourceOneOver =
      !binderContextOneOver.ok
      && binderContextOneOver.kind == "resource-exhaustion"
      && binderContextOneOver.code == "AXIOM-KERNEL-001"
      && binderContextOneOver.budget == "context";
    conversionResourceExact =
      conversionExact.ok
      && conversionExact.resources.conversion == 1
      && conversionExact.resources.comparison == 1;
    conversionResourceOneOver =
      !conversionOneOver.ok && conversionOneOver.kind == "resource-exhaustion";
    readbackResourceExact =
      readbackExact.ok && readbackExact.resources.readback == 1 && readbackExact.resources.output == 1;
    readbackResourceOneOver = !readbackOneOver.ok && readbackOneOver.kind == "resource-exhaustion";
    levelOutputExact = universeQuotationExact.ok && universeQuotationExact.resources.output == 2;
    levelOutputOneOver =
      !universeQuotationOneOver.ok
      && universeQuotationOneOver.kind == "resource-exhaustion"
      && universeQuotationOneOver.budget == "output";
    oracleSharedResourceExact =
      oracleSharedExact.ok
      && oracleSharedExact.resources.readback == 2
      && oracleSharedExact.resources.output == 2;
    oracleSharedResourceOneOver =
      !oracleSharedOneOver.ok
      && oracleSharedOneOver.kind == "resource-exhaustion"
      && oracleSharedOneOver.budget == "readback";
    trustedFamiliesExact =
      kernelResult.validators.checkedContext trustedContext
      && kernelResult.validators.formation trustedFormation
      && kernelResult.validators.inference trustedInference
      && kernelResult.validators.checking trustedChecking
      && kernelResult.validators.typeConversion trustedTypeConversion
      && kernelResult.validators.termConversion trustedTermConversion
      && kernelResult.validators.readback trustedReadback
      && kernelResult.validators.quotation trustedQuotation
      && kernelResult.validators.oracle trustedOracle;
    hostileTrustedRejected = hostileRejected;
    generatedConversionOracleAgreement = generatedAgreement;
    rejectedEtaControls = sumEtaControl && emptyEtaControl && identityEtaControl;
    typedEliminatorReplay = unitElimination.ok && unitEliminationReadback.ok;
    longSpineReplay =
      longSpineContextResult.ok
      && longSpineInference.ok
      && longSpineReadback.ok
      && longSpineReadback.value.root.kind == "unit";
    canonicityUnit = canonicalUnitReadback.ok && canonicalUnitReadback.value.root.kind == "unit";
    openNeutralProgress =
      openNeutralReadback.ok
      && openNeutralReadback.value.root.kind == "variable"
      && openNeutralReadback.resources.depth == 1;
  }
  # the operation, observer, and mutation modules own their own evidence and
  # arrive here as ordinary leaves
  // (import ./operations.nix).evidence
  // (import ./mutations/runner.nix).evidence
  // (import ./baseline.nix).evidence;
  failed = builtins.attrNames (
    builtins.removeAttrs evidence (
      builtins.filter (name: evidence.${name}) (builtins.attrNames evidence)
    )
  );
in
{
  inherit evidence;
  ok =
    if builtins.all (name: evidence.${name}) (builtins.attrNames evidence) then
      true
    else
      throw "axiom kernel tests FAILED: ${builtins.concatStringsSep ", " failed}";
}
