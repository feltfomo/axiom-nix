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
  privateGraph = (import ./observed-graph.nix).silent { };
  conversionHandlerKeys = privateGraph.kernel.components.conversion.handlerKeys;
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
  invalidConversionType = sem.unit // {
    kind = "unit";
  };
  invalidConversionTypeResult = kernel.convertTerms {
    contextValue = emptyContext;
    type = invalidConversionType;
    left = sem.unit;
    right = sem.unit;
  };
  dependentPiSyntax = r.pi r.unitType (r.identityType r.unitType (r.variable 0) (r.variable 0));
  dependentPiType = kernel.infer {
    contextValue = emptyContext;
    envelope = r.envelope 0 dependentPiSyntax [ ];
  };
  dependentPiLeft = kernel.check {
    contextValue = emptyContext;
    envelope = r.envelope 0 (r.lambda (r.refl (r.variable 0))) [ ];
    expected = dependentPiType.value;
  };
  dependentPiRight = kernel.check {
    contextValue = emptyContext;
    envelope = r.envelope 0 (r.lambda (r.refl (r.variable 0))) [ ];
    expected = dependentPiType.value;
  };
  dependentPiConversion = kernel.convertTerms {
    contextValue = emptyContext;
    type = dependentPiType.value;
    left = dependentPiLeft.value;
    right = dependentPiRight.value;
  };
  pointwiseIdentityLeft = sem.identityType (sem.valueCell (
    sem.universe core.levels.zero
  )) (sem.valueCell sem.unitType) (sem.valueCell sem.unitType);
  pointwiseIdentityRight = sem.identityType (sem.valueCell (
    sem.universe core.levels.zero
  )) (sem.valueCell sem.unitType) (sem.valueCell sem.emptyType);
  pointwiseIdentityResult = kernel.convertTypes {
    contextValue = emptyContext;
    left = pointwiseIdentityLeft;
    right = pointwiseIdentityRight;
  };
  dependentSigmaType = sem.sigma (sem.valueCell (sem.universe core.levels.zero)) (
    sem.closure (sem.initialEnvironment 0) r.unitType
  );
  dependentSigmaFailureAttempt = builtins.tryEval (
    kernel.convertTerms {
      contextValue = emptyContext;
      type = dependentSigmaType;
      left = sem.pair (sem.valueCell sem.unitType) (builtins.throw "left second projection forced");
      right = sem.pair (sem.valueCell sem.emptyType) (builtins.throw "right second projection forced");
    }
  );
  failedLeftApplicationAttempt = builtins.tryEval (
    kernel.convertTerms {
      contextValue = emptyContext;
      type = sem.pi (sem.valueCell sem.unitType) (
        builtins.throw "codomain forced after failed left application"
      );
      left = sem.closure (sem.initialEnvironment 0) (r.variable 99);
      right = sem.closure (sem.initialEnvironment 0) (builtins.throw "right application forced");
    }
  );
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
  resourceVector =
    overrides:
    {
      application = 0;
      checking = 0;
      comparison = 0;
      context = 0;
      conversion = 0;
      demand = 0;
      depth = 0;
      output = 0;
      projection = 0;
      readback = 0;
      transition = 0;
    }
    // overrides;
  privateBudget = privateGraph.kernel.components.budget;
  privateComputation = privateGraph.logismos.public.computation;
  privateSemantic = import ../../language/kernel/semantic.nix {
    inherit core evaluation;
    representation = kernelRepresentation;
    result = kernelResult;
    budget = privateBudget;
    logismos = privateGraph.logismos.public;
  };
  privateLimits = overrides: (privateBudget.merge overrides).value;
  runPrivate =
    judgment: limits: program:
    privateComputation.run {
      computation = program;
      reader = { inherit judgment; };
      state = privateBudget.initial // {
        inherit limits;
      };
    };
  privateResources = executed: kernelRepresentation.resources executed.state;
  semanticClosure = sem.closure (sem.initialEnvironment 0) r.unit;
  demandExact = runPrivate "demand" (privateLimits { demand = 1; }) (
    privateSemantic.demand "demand" (privateLimits { demand = 1; }) 0 (sem.valueCell sem.unit)
  );
  demandOneOverAttempt = builtins.tryEval (
    runPrivate "demand" (privateLimits { demand = 0; }) (
      privateSemantic.demand "demand" (privateLimits { demand = 0; }) 0 (
        builtins.throw "demand cell inspected"
      )
    )
  );
  demandOneOver = demandOneOverAttempt.value;
  applicationExact = runPrivate "application" (privateLimits { application = 1; }) (
    privateSemantic.apply "application" (privateLimits { application = 1; }) 0 semanticClosure (
      sem.valueCell sem.unit
    )
  );
  applicationOneOverAttempt = builtins.tryEval (
    runPrivate "application" (privateLimits { application = 0; }) (
      privateSemantic.apply "application" (privateLimits { application = 0; }) 0
        (builtins.throw "application function inspected")
        (builtins.throw "application argument inspected")
    )
  );
  applicationOneOver = applicationOneOverAttempt.value;
  projectionValue = sem.pair (sem.valueCell sem.unit) (sem.valueCell sem.unit);
  projectionExact =
    runPrivate "projection"
      (privateLimits {
        demand = 1;
        projection = 1;
      })
      (
        privateSemantic.project "projection" (privateLimits {
          demand = 1;
          projection = 1;
        }) 0 "first" projectionValue
      );
  projectionOneOverAttempt = builtins.tryEval (
    runPrivate "projection" (privateLimits { projection = 0; }) (
      privateSemantic.project "projection" (privateLimits { projection = 0; }) 0 "first" (
        builtins.throw "projection value inspected"
      )
    )
  );
  projectionOneOver = projectionOneOverAttempt.value;
  applyManyArguments = [
    (sem.valueCell sem.unit)
    (sem.valueCell sem.unit)
    (sem.valueCell sem.unit)
  ];
  applyManyExact = runPrivate "application" (privateLimits { application = 3; }) (
    privateSemantic.applyMany "application" (privateLimits {
      application = 3;
    }) 0 semanticClosure applyManyArguments
  );
  mixedExactLimits = privateLimits {
    application = 1;
    demand = 1;
    projection = 1;
  };
  mixedProgram =
    limits:
    privateComputation.bind (privateSemantic.project "mixed" limits 0 "first" projectionValue) (
      projected: privateSemantic.apply "mixed" limits 0 semanticClosure (sem.valueCell projected)
    );
  mixedExact = runPrivate "mixed" mixedExactLimits (mixedProgram mixedExactLimits);
  mixedDemandOneOverLimits = privateLimits {
    application = 1;
    demand = 0;
    projection = 1;
  };
  mixedDemandOneOver = runPrivate "mixed" mixedDemandOneOverLimits (
    mixedProgram mixedDemandOneOverLimits
  );
  mixedApplicationOneOverLimits = privateLimits {
    application = 0;
    demand = 1;
    projection = 1;
  };
  mixedApplicationOneOver = runPrivate "mixed" mixedApplicationOneOverLimits (
    mixedProgram mixedApplicationOneOverLimits
  );
  comparisonOneOverAttempt = builtins.tryEval (
    kernel.convertTerms {
      contextValue = emptyContext;
      type = sem.unitType;
      left = builtins.throw "comparison left inspected";
      right = builtins.throw "comparison right inspected";
      limits = {
        comparison = 0;
        conversion = 1;
      };
    }
  );
  unknownCostAttempt = builtins.tryEval (
    runPrivate "budget" (privateLimits { }) (
      privateBudget.protect "budget" (privateLimits { }) "unknownCost" 0 (
        _charged: builtins.throw "unknown cost continuation opened"
      )
    )
  );
  negativeAmountAttempt = builtins.tryEval (
    runPrivate "budget" (privateLimits { }) (
      privateComputation.bind (privateBudget.chargeNamedAmount "budget" (privateLimits
        { }
      ) "demandCell" 0 (-1)) (_charged: builtins.throw "negative amount continuation opened")
    )
  );
  completeNamedCosts = builtins.all (
    value:
    builtins.attrNames value == builtins.attrNames kernel.limits && privateBudget.algebra.valid value
  ) (builtins.attrValues privateBudget.namedCosts);
  fallbackConversion = kernel.check {
    contextValue = emptyContext;
    envelope = r.envelope 0 r.unitType [ ];
    expected = sem.universe core.levels.zero;
  };
  typeConversionExact = kernel.convertTypes {
    contextValue = emptyContext;
    left = sem.unitType;
    right = sem.unitType;
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
  quoteNeutralOneOverAttempt = builtins.tryEval (
    kernel.quote {
      contextValue = emptyVariableContext;
      type = sem.emptyType;
      value = emptyVariable.value // {
        head = builtins.throw "quote-neutral payload inspected";
      };
      limits = {
        output = 1;
        readback = 1;
      };
    }
  );
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
  typedNeutralReplayConversion = kernel.convertTerms {
    contextValue = unitContext;
    type = sem.universe core.levels.zero;
    left = unitElimination.value;
    right = unitElimination.value;
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
  transition = privateGraph.kernel.components.neutralTransition;
  transitionBudget = privateGraph.kernel.components.budget;
  transitionResult = privateGraph.kernel.components.result;
  transitionComputation = privateGraph.logismos.public.computation;
  transitionLimits = (transitionBudget.merge { }).value;
  transitionHead = sem.neutral 0;
  applyClosure =
    closure: arguments:
    let
      environment = builtins.foldl' (
        current: argument: (sem.extendEnvironment current (sem.valueCell argument)).value
      ) closure.environment arguments;
    in
    evaluation.direct.runRoot {
      inherit environment;
      root = closure.body;
    };
  runTransition =
    {
      type,
      item,
      expectedType,
      limits ? transitionLimits,
    }:
    let
      executed = transitionComputation.run {
        computation = transition.replay {
          judgment = "conversion";
          inherit limits;
          ctx = unitContext;
          initial = {
            inherit type;
            value = transitionHead;
            observer = null;
          };
          spine = [ item ];
          spineCount = 1;
          peerValue = transitionHead;
          peerSpine = [ item ];
          peerSpineCount = 1;
          malformed = transitionResult.internal "conversion" 1 transitionResult.codes.malformedSemantic;
          mismatch =
            transitionResult.failure "conversion" 1 transitionResult.codes.mismatch [ ] "convertible"
              "distinct";
          observe = _descriptor: observer: transitionComputation.pure observer;
        };
        reader = {
          judgment = "conversion";
        };
        state = transitionBudget.initial;
      };
      expectedValue = sem.extendNeutral transitionHead item;
    in
    {
      inherit executed expectedType expectedValue;
      exact =
        executed.kind == "success"
        && executed.value.type == expectedType
        && executed.value.value == expectedValue
        && executed.value.peerValue == expectedValue;
    };
  dependentIdentity = carrier: level: r.identityType carrier (r.variable level) (r.variable level);
  applicationCodomain = sem.closure (sem.initialEnvironment 0) (dependentIdentity r.unitType 0);
  applicationItem = sem.spineItem {
    kind = "application";
    argument = sem.valueCell sem.unit;
  };
  applicationTransition = runTransition {
    type = sem.pi (sem.valueCell sem.unitType) applicationCodomain;
    item = applicationItem;
    expectedType = (applyClosure applicationCodomain [ sem.unit ]).value;
  };
  transitionResourceExactCase = runTransition {
    type = sem.pi (sem.valueCell sem.unitType) applicationCodomain;
    item = applicationItem;
    expectedType = (applyClosure applicationCodomain [ sem.unit ]).value;
    limits = (transitionBudget.merge { transition = 2; }).value;
  };
  transitionResourceOneOverCase = runTransition {
    type = sem.pi (sem.valueCell sem.unitType) applicationCodomain;
    item = applicationItem;
    expectedType = (applyClosure applicationCodomain [ sem.unit ]).value;
    limits = (transitionBudget.merge { transition = 1; }).value;
  };
  sigmaCodomain = sem.closure (sem.initialEnvironment 0) (dependentIdentity r.unitType 0);
  firstProjectionItem = sem.spineItem { kind = "first-projection"; };
  firstProjectionTransition = runTransition {
    type = sem.sigma (sem.valueCell sem.unitType) sigmaCodomain;
    item = firstProjectionItem;
    expectedType = sem.unitType;
  };
  semanticFirstProjection = sem.extendNeutral transitionHead firstProjectionItem;
  secondProjectionItem = sem.spineItem { kind = "second-projection"; };
  secondProjectionTransition = runTransition {
    type = sem.sigma (sem.valueCell (sem.universe r.levelZero)) sigmaCodomain;
    item = secondProjectionItem;
    expectedType = (applyClosure sigmaCodomain [ semanticFirstProjection ]).value;
  };
  sumMotiveClosure = sem.closure (sem.initialEnvironment 0) (
    dependentIdentity (r.sumType r.unitType r.unitType) 0
  );
  sumEliminationItem = sem.spineItem {
    kind = "sum-elimination";
    motive = sumMotiveClosure;
    leftBranch = sem.closure (sem.initialEnvironment 0) (r.refl (r.leftInjection (r.variable 0)));
    rightBranch = sem.closure (sem.initialEnvironment 0) (r.refl (r.rightInjection (r.variable 0)));
  };
  sumEliminationTransition = runTransition {
    type = sem.sumType (sem.valueCell (sem.universe r.levelZero)) (
      sem.valueCell (sem.universe r.levelZero)
    );
    item = sumEliminationItem;
    expectedType = (applyClosure sumMotiveClosure [ transitionHead ]).value;
  };
  unitMotiveClosure = sem.closure (sem.initialEnvironment 0) (dependentIdentity r.unitType 0);
  unitEliminationItem = sem.spineItem {
    kind = "unit-elimination";
    motive = unitMotiveClosure;
    case = sem.valueCell (sem.refl (sem.valueCell sem.unit));
  };
  unitEliminationTransition = runTransition {
    type = sem.unitType;
    item = unitEliminationItem;
    expectedType = (applyClosure unitMotiveClosure [ transitionHead ]).value;
  };
  emptyMotiveClosure = sem.closure (sem.initialEnvironment 0) (dependentIdentity r.emptyType 0);
  emptyEliminationItem = sem.spineItem {
    kind = "empty-elimination";
    motive = emptyMotiveClosure;
  };
  emptyEliminationTransition = runTransition {
    type = sem.emptyType;
    item = emptyEliminationItem;
    expectedType = (applyClosure emptyMotiveClosure [ transitionHead ]).value;
  };
  identityMotiveClosure = sem.closure (sem.initialEnvironment 0) (
    r.identityType (r.identityType r.unitType (r.variable 0) (r.variable 1)) (r.variable 2) (
      r.variable 2
    )
  );
  identityEliminationItem = sem.spineItem {
    kind = "identity-elimination";
    motive = identityMotiveClosure;
    reflBranch = sem.closure (sem.initialEnvironment 0) (r.refl (r.refl (r.variable 0)));
  };
  identitySource = sem.unitType;
  identityTarget = sem.unitType;
  identityEliminationTransition = runTransition {
    type = sem.identityType (sem.valueCell (sem.universe r.levelZero)) (sem.valueCell identitySource) (
      sem.valueCell identityTarget
    );
    item = identityEliminationItem;
    expectedType =
      (applyClosure identityMotiveClosure [
        identitySource
        identityTarget
        transitionHead
      ]).value;
  };
  transitionFamilyResults = [
    applicationTransition
    firstProjectionTransition
    secondProjectionTransition
    sumEliminationTransition
    unitEliminationTransition
    emptyEliminationTransition
    identityEliminationTransition
  ];
  readbackCase =
    {
      entryType,
      term,
      expectedTerm ? term,
    }:
    let
      contextResult = checked [ entryType ];
      inferred = kernel.infer {
        contextValue = contextResult.context;
        envelope = r.envelope 1 term [ ];
      };
      quoted =
        if inferred.ok then
          kernel.quote {
            contextValue = contextResult.context;
            inherit (inferred) type value;
          }
        else
          inferred;
      expected = r.envelope 1 expectedTerm [ ];
    in
    {
      inherit
        contextResult
        inferred
        quoted
        expected
        ;
      exact = contextResult.ok && inferred.ok && quoted.ok && quoted.value == expected;
    };
  transitionReadbacks = {
    application = readbackCase {
      entryType = r.pi r.unitType (dependentIdentity r.unitType 0);
      term = r.application (r.variable 0) r.unit;
    };
    firstProjection = readbackCase {
      entryType = r.sigma r.emptyType (dependentIdentity r.emptyType 0);
      term = r.firstProjection (r.variable 0);
    };
    secondProjection = readbackCase {
      entryType = r.sigma r.unitType (dependentIdentity r.unitType 0);
      term = r.secondProjection (r.variable 0);
    };
    sumElimination = readbackCase {
      entryType = r.sumType (r.universe r.levelZero) (r.universe r.levelZero);
      term =
        r.sumElimination (r.variable 0)
          (dependentIdentity (r.sumType (r.universe r.levelZero) (r.universe r.levelZero)) 1)
          (r.refl (r.leftInjection (r.variable 1)))
          (r.refl (r.rightInjection (r.variable 1)));
    };
    unitElimination = readbackCase {
      entryType = r.unitType;
      term = r.unitElimination (r.variable 0) (dependentIdentity r.unitType 1) (r.refl r.unit);
      expectedTerm = r.unitElimination (r.variable 0) (r.identityType r.unitType r.unit r.unit) (
        r.refl r.unit
      );
    };
    emptyElimination = readbackCase {
      entryType = r.emptyType;
      term = r.emptyElimination (r.variable 0) (dependentIdentity r.emptyType 1);
    };
    identityElimination = readbackCase {
      entryType = r.identityType (r.universe r.levelZero) r.unitType r.unitType;
      term = r.identityElimination (r.variable 0) (r.identityType (r.identityType (r.universe r.levelZero)
        (r.variable 1)
        (r.variable 2)
      ) (r.variable 3) (r.variable 3)) (r.refl (r.refl (r.variable 1)));
    };
  };
  transitionReadbackResults = builtins.attrValues transitionReadbacks;
  argumentType = r.universe r.levelZero;
  argumentFunctionType = r.pi argumentType (dependentIdentity argumentType 0);
  applicationArgumentLeft = readbackCase {
    entryType = argumentFunctionType;
    term = r.application (r.variable 0) r.unitType;
  };
  applicationArgumentRight = readbackCase {
    entryType = argumentFunctionType;
    term = r.application (r.variable 0) r.emptyType;
  };
  transitionOrderTerm =
    r.unitElimination (r.application (r.variable 0) r.unit) (r.universe r.levelZero)
      r.unitType;
  transitionOrderCase = readbackCase {
    entryType = r.pi r.unitType r.unitType;
    term = transitionOrderTerm;
  };
  transitionOrderKinds = map (item: item.kind) transitionOrderCase.inferred.value.spine;
  pairedFunctionType = r.pi argumentType (r.pi argumentType r.emptyType);
  pairedContext = (checked [ pairedFunctionType ]).context;
  pairedLeft = kernel.infer {
    contextValue = pairedContext;
    envelope = r.envelope 1 (r.application (r.application (r.variable 0) r.unitType) r.unitType) [ ];
  };
  pairedRight = kernel.infer {
    contextValue = pairedContext;
    envelope = r.envelope 1 (r.application (r.application (r.variable 0) r.unitType) r.emptyType) [ ];
  };
  pairedEqual = kernel.convertTerms {
    contextValue = pairedContext;
    type = sem.emptyType;
    left = pairedLeft.value;
    right = pairedLeft.value;
  };
  pairedChanged = kernel.convertTerms {
    contextValue = pairedContext;
    type = sem.emptyType;
    left = pairedLeft.value;
    right = pairedRight.value;
  };
  transitionOrderLarge = kernel.quote {
    contextValue = transitionOrderCase.contextResult.context;
    inherit (transitionOrderCase.inferred) type value;
    limits = {
      checking = 4096;
      comparison = 4096;
      context = 256;
      conversion = 4096;
      depth = 64;
      output = 256;
      readback = 4096;
    };
  };
  sumLeftFailureCase = readbackCase {
    entryType = r.sumType r.unitType r.unitType;
    term =
      r.sumElimination (r.variable 0) (dependentIdentity (r.sumType r.unitType r.unitType) 1)
        (r.variable 99)
        (builtins.throw "right branch forced after left failure");
  };
  sumLeftFailureAttempt = builtins.tryEval sumLeftFailureCase.inferred.ok;
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
  conversionSource = builtins.readFile ../../language/kernel/conversion.nix;
  conversionSections = builtins.split "\n  oracle =\n" conversionSource;
  optimizedConversionSource = builtins.elemAt conversionSections 0;
  oracleConversionSource = builtins.elemAt conversionSections 2;
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
  readbackSource = builtins.readFile ../../language/kernel/readback.nix;
  transitionSource = builtins.readFile ../../language/kernel/neutral-transition.nix;
  semanticSource = builtins.readFile ../../language/kernel/semantic.nix;
  budgetSource = builtins.readFile ../../language/kernel/budget.nix;
  representationSource = builtins.readFile ../../language/kernel/representation.nix;
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
      "neutralElimination"
    ];
  structuralReconciliation =
    builtins.all (text: !(contains "builtins.genericClosure" text)) structuralSources
    && !(forbiddenPlanText transitionSource)
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
    && contains "inferProgram" checkingSource
    && contains "checkProgram" checkingSource
    && contains "formProgram" checkingSource
    && !(contains "runProgram =" checkingSource)
    && !(contains "kernelState" checkingSource)
    && !(contains "worklist" checkingSource)
    && !(contains "formAt =" checkingSource)
    && !(contains "inferAt =" checkingSource)
    && !(contains "checkAt =" checkingSource)
    && contains "neutralTransition.replay" readbackSource
    && contains "reflect =" readbackSource
    && contains "reify = quoteValue" readbackSource
    && contains "sem.extendNeutral d.value d.item" transitionSource
    && !(contains "extendNeutral" readbackSource)
    && !(contains "boundedNewestFirst" representationSource)
    && !(contains "internal/worklist" representationSource)
    && !(contains "builtins.tail" transitionSource)
    && !(contains "builtins.tail" readbackSource)
    && !(contains "  flow," checkingSource)
    && !(contains "semanticOps" checkingSource)
    && !(contains "resources." checkingSource)
    && !(contains "flow.andThen" readbackSource)
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
  completeVectorObservations = {
    simpleInference = checkingExact.resources;
    suppliedContext = contextExact.resources;
    computedBinderContext = binderContextExact.resources;
    publicTypeConversion = typeConversionExact.resources;
    publicTermConversion = conversionExact.resources;
    checkingFallbackConversion = fallbackConversion.resources;
    dependentComparison = dependentPiConversion.resources;
    demand = privateResources demandExact;
    application = privateResources applicationExact;
    projection = privateResources projectionExact;
    applyMany = privateResources applyManyExact;
    plainValueReadback = readbackExact.resources;
    quoteNeutral = openNeutralReadback.resources;
    normalizedLevelOutput = universeQuotationExact.resources;
    typedReplay = typedNeutralReplayConversion.resources;
    transition = privateResources transitionResourceExactCase.executed;
    canonicalReadbackOracle = oracleSharedExact.resources;
    mixedOperations = privateResources mixedExact;
  };
  completeVectorExpectations = {
    simpleInference = resourceVector { checking = 1; };
    suppliedContext = resourceVector {
      checking = 1;
      context = 1;
      depth = 1;
    };
    computedBinderContext = resourceVector {
      checking = 3;
      context = 1;
      depth = 1;
    };
    publicTypeConversion = resourceVector {
      comparison = 1;
      conversion = 1;
    };
    publicTermConversion = resourceVector {
      comparison = 1;
      conversion = 1;
    };
    checkingFallbackConversion = resourceVector {
      checking = 2;
      comparison = 1;
      conversion = 1;
    };
    dependentComparison = resourceVector {
      application = 3;
      comparison = 3;
      context = 1;
      conversion = 1;
      demand = 4;
      depth = 1;
    };
    demand = resourceVector { demand = 1; };
    application = resourceVector { application = 1; };
    projection = resourceVector {
      demand = 1;
      projection = 1;
    };
    applyMany = resourceVector { application = 3; };
    plainValueReadback = resourceVector {
      output = 1;
      readback = 1;
    };
    quoteNeutral = resourceVector {
      depth = 1;
      output = 1;
      readback = 2;
    };
    normalizedLevelOutput = resourceVector {
      output = 2;
      readback = 1;
    };
    typedReplay = resourceVector {
      application = 4;
      comparison = 6;
      context = 1;
      conversion = 1;
      demand = 2;
      depth = 2;
      transition = 2;
    };
    transition = resourceVector {
      application = 1;
      depth = 1;
      transition = 2;
    };
    canonicalReadbackOracle = resourceVector {
      output = 2;
      readback = 2;
    };
    mixedOperations = resourceVector {
      application = 1;
      demand = 1;
      projection = 1;
    };
  };
  completeVectorCases = map (
    name:
    resourceFixture {
      inherit name;
      expected = completeVectorExpectations.${name};
      actual = completeVectorObservations.${name};
    }
  ) (builtins.attrNames completeVectorExpectations);
  completeVectorsExact =
    builtins.attrNames completeVectorObservations == builtins.attrNames completeVectorExpectations
    && builtins.all (case: case.pass) completeVectorCases;
  privateRefusal =
    budgetName: limit: consumed: execution:
    execution.kind == "failure"
    && execution.failure.kind == "resource-exhaustion"
    && execution.failure.code == "AXIOM-KERNEL-001"
    && execution.failure.budget == budgetName
    && execution.failure.limit == limit
    && execution.failure.consumed == consumed;
  internalBudgetFailure =
    attempted:
    attempted.success
    && attempted.value.kind == "failure"
    && attempted.value.failure.kind == "internal-failure"
    && attempted.value.failure.code == "AXIOM-KERNEL-008"
    && privateResources attempted.value == resourceVector { };
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
    privateGeneration = kernel.generation == "axiom-kernel-2";
    resourceCompleteVectors = completeVectorsExact;
    demandResourceExact =
      demandExact.kind == "success" && privateResources demandExact == completeVectorExpectations.demand;
    demandResourceOneOver =
      demandOneOverAttempt.success
      && privateRefusal "demand" 0 0 demandOneOver
      && privateResources demandOneOver == resourceVector { };
    applicationResourceExact =
      applicationExact.kind == "success"
      && privateResources applicationExact == completeVectorExpectations.application;
    applicationResourceOneOver =
      applicationOneOverAttempt.success
      && privateRefusal "application" 0 0 applicationOneOver
      && privateResources applicationOneOver == resourceVector { };
    projectionResourceExact =
      projectionExact.kind == "success"
      && privateResources projectionExact == completeVectorExpectations.projection;
    projectionResourceOneOver =
      projectionOneOverAttempt.success
      && privateRefusal "projection" 0 0 projectionOneOver
      && privateResources projectionOneOver == resourceVector { };
    applyManyResourceExact =
      applyManyExact.kind == "success"
      && builtins.length applyManyArguments == 3
      && privateResources applyManyExact == completeVectorExpectations.applyMany;
    quoteNeutralResourceExact =
      openNeutralReadback.resources == completeVectorExpectations.quoteNeutral;
    quoteNeutralResourceOneOver =
      quoteNeutralOneOverAttempt.success
      && !quoteNeutralOneOverAttempt.value.ok
      && quoteNeutralOneOverAttempt.value.kind == "resource-exhaustion"
      && quoteNeutralOneOverAttempt.value.code == "AXIOM-KERNEL-001"
      && quoteNeutralOneOverAttempt.value.budget == "readback"
      && quoteNeutralOneOverAttempt.value.limit == 1
      && quoteNeutralOneOverAttempt.value.consumed == 1;
    checkingFallbackConversionExact =
      fallbackConversion.ok
      && fallbackConversion.resources == completeVectorExpectations.checkingFallbackConversion;
    comparisonResourceOneOver =
      comparisonOneOverAttempt.success
      && !comparisonOneOverAttempt.value.ok
      && comparisonOneOverAttempt.value.kind == "resource-exhaustion"
      && comparisonOneOverAttempt.value.code == "AXIOM-KERNEL-001"
      && comparisonOneOverAttempt.value.budget == "comparison"
      && comparisonOneOverAttempt.value.limit == 0
      && comparisonOneOverAttempt.value.consumed == 0;
    mixedResourceLimitsIndependent =
      mixedExact.kind == "success"
      && privateResources mixedExact == completeVectorExpectations.mixedOperations
      && privateRefusal "demand" 0 0 mixedDemandOneOver
      && privateResources mixedDemandOneOver == resourceVector { projection = 1; }
      && privateRefusal "application" 0 0 mixedApplicationOneOver
      &&
        privateResources mixedApplicationOneOver == resourceVector {
          demand = 1;
          projection = 1;
        };
    namedCostsCompleteAndValid = completeNamedCosts;
    unknownNamedCostFailsClosed = internalBudgetFailure unknownCostAttempt;
    negativeNamedAmountFailsClosed = internalBudgetFailure negativeAmountAttempt;
    conversionHandlerKeysExact =
      conversionHandlerKeys.type == conversionHandlerKeys.producerType
      && conversionHandlerKeys.value == conversionHandlerKeys.producerValue
      && conversionHandlerKeys.type == evaluation.representation.schema.conversionRoles.typeKinds
      && conversionHandlerKeys.value == evaluation.representation.schema.conversionRoles.valueKinds;
    optimizedReadbackBoundary =
      builtins.length conversionSections == 3
      && !(contains "readback." optimizedConversionSource)
      && !(contains "quoteAt" optimizedConversionSource)
      && !(contains "oracle" optimizedConversionSource)
      && contains "readback.quoteAt" oracleConversionSource;
    transitionExportSetExact =
      builtins.attrNames transition == [
        "advance"
        "applicationArguments"
        "applicationDomain"
        "emptyMotive"
        "identityBranches"
        "identityMotive"
        "kinds"
        "observePhase"
        "prepare"
        "replay"
        "sumBranch"
        "sumMotive"
        "typeKinds"
        "unitCases"
        "unitMotive"
      ];
    transitionFactoryProduction = privateGraph.kernel.wiring.transitionAdvance == "production";
    transitionKindsExact =
      transition.kinds == builtins.attrNames evaluation.representation.schema.spineItemFields
      && builtins.attrNames transition.typeKinds == transition.kinds;
    transitionSuccessorsExact = builtins.all (case: case.exact) transitionFamilyResults;
    transitionEnvelopesExact = builtins.all (case: case.exact) transitionReadbackResults;
    transitionBinderSensitive =
      transitionReadbacks.application.exact
      && transitionReadbacks.secondProjection.exact
      && transitionReadbacks.sumElimination.exact
      && transitionReadbacks.unitElimination.exact
      && transitionReadbacks.identityElimination.exact;
    transitionSumFailureStopsRight = sumLeftFailureAttempt.success && !sumLeftFailureAttempt.value;
    transitionExtensionMetamorphic = builtins.all (
      case:
      case.executed.kind == "success"
      && case.executed.value.value == case.expectedValue
      && case.executed.value.peerValue == case.expectedValue
      && case.executed.value.value.spine == case.expectedValue.spine
      && case.executed.value.peerValue.spine == case.expectedValue.spine
    ) transitionFamilyResults;
    transitionOldestFirst =
      transitionOrderCase.exact
      && transitionOrderCase.inferred.value.spineCount == 2
      &&
        transitionOrderKinds == [
          "unit-elimination"
          "application"
        ];
    transitionArgumentMetamorphic =
      applicationArgumentLeft.exact
      && applicationArgumentRight.exact
      && applicationArgumentLeft.expected != applicationArgumentRight.expected;
    transitionPairedMetamorphic = pairedEqual.ok && !pairedChanged.ok;
    transitionResourceExact =
      transitionResourceExactCase.exact
      && privateResources transitionResourceExactCase.executed == completeVectorExpectations.transition;
    transitionResourceOneOver =
      transitionResourceOneOverCase.executed.kind == "failure"
      && transitionResourceOneOverCase.executed.failure.kind == "resource-exhaustion"
      && transitionResourceOneOverCase.executed.failure.code == "AXIOM-KERNEL-001"
      && transitionResourceOneOverCase.executed.failure.budget == "transition"
      && transitionResourceOneOverCase.executed.failure.limit == 1
      && transitionResourceOneOverCase.executed.failure.consumed == 0;
    transitionLimitMetamorphic =
      transitionOrderLarge.ok && transitionOrderLarge.value == transitionOrderCase.quoted.value;
    invalidConversionTypeRejected =
      !invalidConversionTypeResult.ok
      && invalidConversionTypeResult.kind == "internal-failure"
      && invalidConversionTypeResult.code == "AXIOM-KERNEL-006";
    binderSensitivePiIdentityCodomain =
      dependentPiType.ok && dependentPiLeft.ok && dependentPiRight.ok && dependentPiConversion.ok;
    pointwiseIdentityEndpointsDistinct = !pointwiseIdentityResult.ok;
    dependentSigmaFirstFailureLazy =
      dependentSigmaFailureAttempt.success && !dependentSigmaFailureAttempt.value.ok;
    failedLeftApplicationLazy =
      failedLeftApplicationAttempt.success && !failedLeftApplicationAttempt.value.ok;
    neutralSigmaProjection = sigmaConversion.ok && sigmaOracle.ok;
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
      !conversionOneOver.ok
      && conversionOneOver.kind == "resource-exhaustion"
      && conversionOneOver.code == "AXIOM-KERNEL-001"
      && conversionOneOver.budget == "conversion"
      && conversionOneOver.limit == 0
      && conversionOneOver.consumed == 0;
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
    typedNeutralConversionReplay = typedNeutralReplayConversion.ok;
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
  debug = {
    resourceObservations = {
      demand = {
        inherit (demandExact) kind;
        resources = privateResources demandExact;
      };
      application = {
        inherit (applicationExact) kind;
        resources = privateResources applicationExact;
      };
      applicationOneOver = {
        inherit (applicationOneOver) kind failure;
        resources = privateResources applicationOneOver;
      };
      projection = {
        inherit (projectionExact) kind;
        resources = privateResources projectionExact;
      };
      projectionOneOver = {
        inherit (projectionOneOver) kind failure;
        resources = privateResources projectionOneOver;
      };
      applyMany = {
        inherit (applyManyExact) kind;
        resources = privateResources applyManyExact;
      };
      mixed = {
        inherit (mixedExact) kind;
        resources = privateResources mixedExact;
      };
      mixedDemandOneOver = {
        inherit (mixedDemandOneOver) kind failure;
        resources = privateResources mixedDemandOneOver;
      };
      mixedApplicationOneOver = {
        inherit (mixedApplicationOneOver) kind failure;
        resources = privateResources mixedApplicationOneOver;
      };
      comparisonOneOver = comparisonOneOverAttempt;
      unknownCost = unknownCostAttempt;
      negativeAmount = negativeAmountAttempt;
      inherit completeNamedCosts;
      simpleInference = checkingExact.resources;
      suppliedContext = contextExact.resources;
      binderContext = binderContextExact.resources;
      typeConversion = typeConversionExact.resources;
      termConversion = conversionExact.resources;
      fallbackConversion = fallbackConversion.resources;
      dependentComparison = dependentPiConversion.resources;
      plainReadback = readbackExact.resources;
      quoteNeutral = openNeutralReadback.resources;
      normalizedOutput = universeQuotationExact.resources;
      typedReplay = typedNeutralReplayConversion.resources;
      oracle = oracleSharedExact.resources;
      transition = privateResources transitionResourceExactCase.executed;
    };
    readbacks = builtins.mapAttrs (_name: case: {
      contextOk = case.contextResult.ok;
      inferOk = case.inferred.ok;
      inferCode = case.inferred.code or null;
      quoteOk = case.quoted.ok;
      quoteCode = case.quoted.code or null;
      inherit (case) exact expected;
      actual = case.quoted.value or null;
    }) transitionReadbacks;
    paired = {
      leftOk = pairedLeft.ok;
      rightOk = pairedRight.ok;
      equalOk = pairedEqual.ok;
      changedOk = pairedChanged.ok;
      changedCode = pairedChanged.code or null;
    };
  };
  ok =
    if builtins.all (name: evidence.${name}) (builtins.attrNames evidence) then
      true
    else
      throw "axiom kernel tests FAILED: ${builtins.concatStringsSep ", " failed}";
}
