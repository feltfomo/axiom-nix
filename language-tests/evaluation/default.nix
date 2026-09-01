{ language }:
let
  core = import ../../language/core;
  evaluation = import ../../language/evaluation { inherit core; };
  inherit (core) representation operations;
  inherit (evaluation) direct machine;
  projection = import ../support/projection.nix { inherit (evaluation) representation result; };
  stack = import ../../language/logismos/stack.nix;
  r = representation;
  admitted =
    scope: root:
    let
      checked = operations.admitted (r.envelope scope root [ ]);
    in
    if checked.ok then checked.value else throw "evaluation fixture failed admission";
  run =
    scope: root:
    let
      envelope = admitted scope root;
    in
    {
      direct = direct.evaluate { inherit envelope; };
      machine = machine.evaluate { inherit envelope; };
    };
  agrees =
    pair:
    pair.direct.ok
    && pair.machine.ok
    && projection.equal {
      left = pair.direct.value;
      right = pair.machine.value;
    }
    && projection.traceEqual pair.direct.trace pair.machine.trace;
  v = r.variable 0;
  id = r.lambda (r.variable 1);
  beta = run 1 (r.application id v);
  piValue = run 1 (r.pi v (r.variable 1));
  sigmaValue = run 1 (r.sigma v (r.variable 1));
  sumValue = run 1 (r.sumType v v);
  pairValue = run 1 (r.pair v r.unit);
  first = run 1 (r.firstProjection (r.pair v r.unit));
  second = run 1 (r.secondProjection (r.pair r.unit v));
  leftCase = run 1 (
    r.sumElimination (r.leftInjection v) (r.variable 1) (r.variable 1) (r.variable 1)
  );
  rightCase = run 1 (
    r.sumElimination (r.rightInjection v) (r.variable 1) (r.variable 1) (r.variable 1)
  );
  unitCase = run 1 (r.unitElimination r.unit (r.variable 1) v);
  emptyNeutral = run 1 (r.emptyElimination v (r.variable 1));
  identityValue = run 1 (r.identityType v v v);
  reflValue = run 1 (r.refl v);
  lambdaValue = run 1 id;
  leftValue = run 1 (r.leftInjection v);
  rightValue = run 1 (r.rightInjection v);
  unitValue = run 1 r.unit;
  jRefl = run 1 (r.identityElimination (r.refl v) (r.variable 3) (r.variable 1));
  neutralApplication = run 1 (r.application v r.unit);
  neutralFirst = run 1 (r.firstProjection v);
  neutralSecond = run 1 (r.secondProjection v);
  neutralCase = run 1 (r.sumElimination v (r.variable 1) (r.variable 1) (r.variable 1));
  neutralUnit = run 1 (r.unitElimination v (r.variable 1) r.unit);
  neutralJ = run 1 (r.identityElimination v (r.variable 3) (r.variable 1));
  projectedSpine = projection.project { value = neutralJ.machine.value; };
  derivedArrow = r.pi v (r.variable 0);
  derivedProduct = r.sigma v (r.variable 0);
  derivedBool = r.sumType r.unitType r.unitType;
  derivedEither = r.sumType v v;
  derivedOption = r.sumType r.unitType v;
  derived = map (term: run 1 term) [
    derivedArrow
    derivedProduct
    derivedBool
    derivedEither
    derivedOption
  ];
  generatedTerm =
    scope: seed:
    let
      modulo = left: right: left - (builtins.div left right) * right;
      first = modulo seed scope;
      second = modulo (seed + 1) scope;
    in
    r.annotation (r.application (r.lambda (r.application (r.variable first) (r.variable scope))) (r.variable second)) (
      r.application (r.variable second) (r.variable first)
    );
  generated = builtins.concatLists (
    map
      (
        scope:
        map (seed: run scope (generatedTerm scope seed)) [
          0
          1
          2
          3
          4
          5
          6
          7
        ]
      )
      [
        1
        2
        3
        4
        5
      ]
  );
  constructorRuns = map (term: run 1 term) [
    v
    id
    (r.application id v)
    (r.annotation v r.unit)
    (r.universe r.levelZero)
    (r.pi v (r.variable 1))
    (r.sigma v (r.variable 1))
    (r.sumType v v)
    r.unitType
    r.unit
    r.emptyType
    (r.pair v r.unit)
    (r.firstProjection v)
    (r.secondProjection v)
    (r.leftInjection v)
    (r.rightInjection v)
    (r.sumElimination v (r.variable 1) (r.variable 1) (r.variable 1))
    (r.unitElimination v (r.variable 1) r.unit)
    (r.emptyElimination v (r.variable 1))
    (r.identityType v v v)
    (r.refl v)
    (r.identityElimination v (r.variable 3) (r.variable 1))
  ];
  nestAnnotations =
    count: tail: if count == 0 then tail else r.annotation (nestAnnotations (count - 1) tail) v;
  leftApplications =
    count: term: if count == 0 then term else r.application (leftApplications (count - 1) term) v;
  exactNode = machine.evaluate {
    envelope = admitted 1 (nestAnnotations 7 v);
    limits.nodes = 8;
  };
  overNode = machine.evaluate {
    envelope = admitted 1 (nestAnnotations 8 v);
    limits.nodes = 8;
  };
  exactDepth = machine.evaluate {
    envelope = admitted 1 (nestAnnotations 4 v);
    limits.depth = 4;
  };
  overDepth = machine.evaluate {
    envelope = admitted 1 (nestAnnotations 5 v);
    limits.depth = 4;
  };
  directExactNode = direct.evaluate {
    envelope = admitted 1 (nestAnnotations 7 v);
    limits.nodes = 8;
  };
  directOverNode = direct.evaluate {
    envelope = admitted 1 (nestAnnotations 8 v);
    limits.nodes = 8;
  };
  directExactDepth = direct.evaluate {
    envelope = admitted 1 (nestAnnotations 4 v);
    limits.depth = 4;
  };
  directOverDepth = direct.evaluate {
    envelope = admitted 1 (nestAnnotations 5 v);
    limits.depth = 4;
  };
  fuelProbe = machine.evaluate { envelope = admitted 1 (r.application id v); };
  exactFuel = machine.evaluate {
    envelope = admitted 1 (r.application id v);
    limits.fuel = fuelProbe.fuel;
  };
  overFuel = machine.evaluate {
    envelope = admitted 1 (r.application id v);
    limits.fuel = fuelProbe.fuel - 1;
  };
  omega = r.application (r.lambda (r.application (r.variable 0) (r.variable 0))) (
    r.lambda (r.application (r.variable 0) (r.variable 0))
  );
  duplicatedRefusal = machine.evaluate {
    envelope = admitted 0 omega;
    limits.fuel = 64;
  };
  deepAnnotation = machine.evaluate { envelope = admitted 1 (nestAnnotations 64 v); };
  deepApplication = machine.evaluate { envelope = admitted 1 (leftApplications 64 v); };
  inactiveOperand = machine.evaluate { envelope = admitted 1 (r.application (r.lambda v) omega); };
  semantic = evaluation.representation;
  stale = value: value // { generation = "axiom-evaluation-1"; };
  missingLevel = direct.runRoot {
    root = v;
    environment = semantic.initialEnvironment 0;
  };
  invalidApplication = direct.runRoot {
    root = r.application v v;
    environment = (semantic.initialEnvironment 1) // {
      cells."0" = semantic.valueCell ((semantic.neutral 0) // { kind = "future"; });
    };
  };
  invalidCell = direct.runRoot {
    root = v;
    environment = (semantic.initialEnvironment 1) // {
      cells."0" = {
        inherit (semantic) generation;
        kind = "future";
      };
    };
  };
  staleEnvironment = direct.runRoot {
    root = v;
    environment = stale (semantic.initialEnvironment 1);
  };
  staleValue = direct.runRoot {
    root = v;
    environment = (semantic.initialEnvironment 1) // {
      cells."0" = semantic.valueCell (stale (semantic.neutral 0));
    };
  };
  machineState = control: frames: {
    status = "running";
    inherit control;
    frames = stack.prependWrittenOrder frames stack.empty;
    usage = {
      depth = 0;
      fuel = 0;
      nodes = 0;
    };
    trace = [ ];
    terminal = null;
    failure = null;
  };
  impossibleState = machine.runState { state = machineState { kind = "future"; } [ ]; };
  staleTerminal = machine.runState {
    state = machineState {
      kind = "return";
      value = stale (semantic.neutral 0);
    } [ ];
  };
  staleArgument = machine.runState {
    state =
      machineState
        {
          kind = "return";
          value = semantic.closure (semantic.initialEnvironment 0) v;
        }
        [
          {
            kind = "apply-operator";
            argument = stale (semantic.thunkCell (semantic.initialEnvironment 0) v);
            depth = 0;
          }
        ];
  };
  staleFrameEnvironment = stale (semantic.initialEnvironment 1);
  frameFailure =
    kind: value: extra:
    machine.runState {
      state =
        machineState
          {
            kind = "return";
            inherit value;
          }
          [
            (
              {
                inherit kind;
                environment = staleFrameEnvironment;
                depth = 0;
              }
              // extra
            )
          ];
    };
  staleFrames = [
    (frameFailure "sum-elimination-scrutinee"
      (semantic.leftInjection (semantic.valueCell (semantic.neutral 0)))
      {
        motive = r.variable 1;
        leftBranch = r.variable 1;
        rightBranch = r.variable 1;
      }
    )
    (frameFailure "sum-elimination-scrutinee" (semantic.neutral 0) {
      motive = r.variable 1;
      leftBranch = r.variable 1;
      rightBranch = r.variable 1;
    })
    (frameFailure "unit-elimination-scrutinee" semantic.unit {
      motive = r.variable 1;
      case = r.unit;
    })
    (frameFailure "unit-elimination-scrutinee" (semantic.neutral 0) {
      motive = r.variable 1;
      case = r.unit;
    })
    (frameFailure "empty-elimination-scrutinee" (semantic.neutral 0) { motive = r.variable 1; })
    (frameFailure "identity-elimination-scrutinee"
      (semantic.refl (semantic.valueCell (semantic.neutral 0)))
      {
        motive = r.variable 3;
        reflBranch = r.variable 1;
      }
    )
    (frameFailure "identity-elimination-scrutinee" (semantic.neutral 0) {
      motive = r.variable 3;
      reflBranch = r.variable 1;
    })
  ];
  staleClosure = stale;
  projectionStaleTopLevel = projection.project {
    value = stale (semantic.neutral 0);
  };
  projectionStaleCell = projection.project {
    value = semantic.pair (stale (semantic.valueCell (semantic.neutral 0))) (
      semantic.valueCell semantic.unit
    );
  };
  projectionStaleContainedValue = projection.project {
    value = semantic.pair (semantic.valueCell (stale (semantic.neutral 0))) (
      semantic.valueCell semantic.unit
    );
  };
  projectionStaleThunkEnvironment = projection.project {
    value = semantic.pair (semantic.thunkCell (stale (semantic.initialEnvironment 0)) r.unit) (
      semantic.valueCell semantic.unit
    );
  };
  staleProjectionValues = [
    (semantic.pi (semantic.valueCell (semantic.neutral 0)) (
      staleClosure (semantic.closure (semantic.initialEnvironment 1) v)
    ))
    (semantic.sigma (semantic.valueCell (semantic.neutral 0)) (
      staleClosure (semantic.closure (semantic.initialEnvironment 1) v)
    ))
    (semantic.extendNeutral (semantic.neutral 0) {
      kind = "sum-elimination";
      motive = staleClosure (semantic.closure (semantic.initialEnvironment 1) (r.variable 1));
      leftBranch = semantic.closure (semantic.initialEnvironment 1) (r.variable 1);
      rightBranch = semantic.closure (semantic.initialEnvironment 1) (r.variable 1);
    })
    (semantic.extendNeutral (semantic.neutral 0) {
      kind = "sum-elimination";
      motive = semantic.closure (semantic.initialEnvironment 1) (r.variable 1);
      leftBranch = staleClosure (semantic.closure (semantic.initialEnvironment 1) (r.variable 1));
      rightBranch = semantic.closure (semantic.initialEnvironment 1) (r.variable 1);
    })
    (semantic.extendNeutral (semantic.neutral 0) {
      kind = "sum-elimination";
      motive = semantic.closure (semantic.initialEnvironment 1) (r.variable 1);
      leftBranch = semantic.closure (semantic.initialEnvironment 1) (r.variable 1);
      rightBranch = staleClosure (semantic.closure (semantic.initialEnvironment 1) (r.variable 1));
    })
    (semantic.extendNeutral (semantic.neutral 0) {
      kind = "unit-elimination";
      motive = staleClosure (semantic.closure (semantic.initialEnvironment 1) (r.variable 1));
      case = semantic.valueCell semantic.unit;
    })
    (semantic.extendNeutral (semantic.neutral 0) {
      kind = "empty-elimination";
      motive = staleClosure (semantic.closure (semantic.initialEnvironment 1) (r.variable 1));
    })
    (semantic.extendNeutral (semantic.neutral 0) {
      kind = "identity-elimination";
      motive = staleClosure (semantic.closure (semantic.initialEnvironment 3) (r.variable 3));
      reflBranch = semantic.closure (semantic.initialEnvironment 1) (r.variable 1);
    })
    (semantic.extendNeutral (semantic.neutral 0) {
      kind = "identity-elimination";
      motive = semantic.closure (semantic.initialEnvironment 3) (r.variable 3);
      reflBranch = staleClosure (semantic.closure (semantic.initialEnvironment 1) (r.variable 1));
    })
    (semantic.closure (stale (semantic.initialEnvironment 0)) v)
  ];
  badCount = count: (semantic.neutral 0) // { spineCount = count; };
  mixedNeutral =
    semantic.extendNeutral
      (semantic.extendNeutral (semantic.extendNeutral (semantic.neutral 0) {
        kind = "first-projection";
      }) { kind = "second-projection"; })
      {
        kind = "empty-elimination";
        motive = semantic.closure (semantic.initialEnvironment 1) (r.variable 1);
      };
  projectedMixed = projection.project { value = mixedNeutral; };
  projectionRefusal = projection.project {
    value = mixedNeutral;
    limit = 1;
  };
  oneNeutral = semantic.extendNeutral (semantic.neutral 0) { kind = "first-projection"; };
  tooSmallCount = oneNeutral // {
    spineCount = 0;
  };
  forcingRuns = {
    unusedApplication = run 1 (r.application (r.lambda v) omega);
    selectedRightSum = run 1 (r.sumElimination (r.rightInjection v) omega omega (r.variable 1));
    firstOnly = run 1 (r.firstProjection (r.pair v omega));
    secondOnly = run 1 (r.secondProjection (r.pair omega v));
    selectedSum = run 1 (r.sumElimination (r.leftInjection v) omega (r.variable 1) omega);
    unitMotive = run 1 (r.unitElimination r.unit omega v);
    emptyMotive = run 1 (r.emptyElimination v omega);
    jReflMotive = run 1 (r.identityElimination (r.refl v) omega (r.variable 1));
    neutralJInactive = run 1 (r.identityElimination v omega omega);
    piInactive = run 1 (r.pi omega omega);
    sigmaInactive = run 1 (r.sigma omega omega);
    sumInactive = run 1 (r.sumType omega omega);
    identityInactive = run 1 (r.identityType omega omega omega);
    reflInactive = run 1 (r.refl omega);
  };
  unrelatedEnvironment = direct.runRoot {
    root = v;
    environment = {
      inherit (semantic) generation;
      nextLevel = 2;
      cells = {
        "0" = semantic.valueCell (semantic.neutral 0);
        "1" = semantic.thunkCell (semantic.initialEnvironment 0) omega;
      };
    };
  };
  malformedDirectLimits = direct.evaluate {
    envelope = admitted 1 v;
    limits.future = 1;
  };
  malformedMachineLimits = machine.evaluate {
    envelope = admitted 1 v;
    limits.future = 1;
  };
  fuelBeforeControl = machine.runState {
    state = machineState { kind = "future"; } [ ];
    limits.fuel = 0;
  };
  projectionValueSensitivity = !projection.primitiveEqual { value = 1; } { value = 2; };
  projectionTraceSensitivity =
    !projection.traceEqual
      [
        {
          kind = "lookup";
          level = 0;
        }
      ]
      [
        {
          kind = "force";
          level = 0;
        }
      ];
  annotationA = run 1 (r.annotation v (r.lambda (r.variable 1)));
  annotationB = run 1 (r.annotation v (r.application v v));
  semanticKinds = trace: map (event: event.kind) (projection.semanticEvents trace);
  unknownTerm = direct.runRoot {
    root = {
      kind = "future";
    };
    environment = semantic.initialEnvironment 0;
  };
  staleCell = direct.runRoot {
    root = v;
    environment = (semantic.initialEnvironment 1) // {
      cells."0" = stale (semantic.valueCell (semantic.neutral 0));
    };
  };
  staleClosureValue = direct.runRoot {
    root = r.application v v;
    environment = (semantic.initialEnvironment 1) // {
      cells."0" = semantic.valueCell (stale (semantic.closure (semantic.initialEnvironment 0) v));
    };
  };
  contains = needle: text: builtins.replaceStrings [ needle ] [ "" ] text != text;
  directSource = builtins.readFile ../../language/evaluation/direct.nix;
  machineSource = builtins.readFile ../../language/evaluation/machine.nix;
  evaluationDefaultSource = builtins.readFile ../../language/evaluation/default.nix;
  # the entry point delegates composition, so the evaluator imports are named by
  # the construction file rather than by the entry point itself
  evaluationConstructSource = builtins.readFile ../../language/evaluation/construct.nix;
  sharedSources = map builtins.readFile [
    ../../language/evaluation/budget.nix
    ../../language/evaluation/representation.nix
    ../../language/evaluation/result.nix
    ../../language/evaluation/schema.nix
  ];
  admittedKinds = [
    "annotation"
    "application"
    "empty-elimination"
    "empty-type"
    "first-projection"
    "identity-elimination"
    "identity-type"
    "lambda"
    "left-injection"
    "pair"
    "pi"
    "refl"
    "right-injection"
    "second-projection"
    "sigma"
    "sum-elimination"
    "sum-type"
    "unit"
    "unit-elimination"
    "unit-type"
    "universe"
    "variable"
  ];
  eliminatorKinds = [
    "empty-elimination"
    "first-projection"
    "identity-elimination"
    "second-projection"
    "sum-elimination"
    "unit-elimination"
  ];
  agreementCorpus = generated ++ constructorRuns ++ builtins.attrValues forcingRuns;
  claimCases = {
    restoredSp3 = [
      "restoredGeneratedAgreement40"
      "exactNodeBoundary"
      "exactDepthBoundary"
      "exactFuelBoundary"
    ];
    constructors = [ "completeConstructorAgreement" ];
    canonical = [
      "canonicalIntroductions"
      "beta"
      "projections"
      "sumComputations"
      "unitComputation"
      "jReflComputation"
    ];
    neutral = [
      "neutralEliminations"
      "neutralSpineCountValidation"
    ];
    forcing = [ "admittedForcingMatrix" ];
    generation = [
      "restoredGenerationBoundaries"
      "projectionClosureGeneration"
    ];
    resources = [
      "oneOverNodeBoundary"
      "oneOverDepthBoundary"
      "oneOverFuelBoundary"
      "boundedProjectionRefusal"
    ];
  };
  cases = {
    restoredGeneratedAgreement40 = builtins.length generated == 40 && builtins.all agrees generated;
    completeAgreementCorpus =
      builtins.length agreementCorpus > 60 && builtins.all agrees agreementCorpus;
    completeConstructorAgreement =
      builtins.length constructorRuns == 22 && builtins.all agrees constructorRuns;
    exactNodeBoundary = exactNode.ok && exactNode.nodes == 8;
    oneOverNodeBoundary = overNode.kind == "resource-exhaustion" && overNode.consumed == 8;
    exactDepthBoundary = exactDepth.ok && exactDepth.nodes == 5;
    oneOverDepthBoundary = overDepth.kind == "resource-exhaustion" && overDepth.dimension == "depth";
    exactFuelBoundary = exactFuel.ok && exactFuel.fuel == fuelProbe.fuel;
    oneOverFuelBoundary = overFuel.kind == "resource-exhaustion" && overFuel.dimension == "fuel";
    directResourceBounds =
      directExactNode.ok
      && directExactNode.nodes == 8
      && directOverNode.kind == "resource-exhaustion"
      && directOverNode.consumed == 8
      && directExactDepth.ok
      && directOverDepth.kind == "resource-exhaustion"
      && directOverDepth.dimension == "depth";
    resourceTraceAgreement =
      projection.traceEqual directOverNode.trace overNode.trace
      && projection.traceEqual directOverDepth.trace overDepth.trace;
    malformedLimitsStable =
      malformedDirectLimits.code == evaluation.result.codes.invalidLimits
      && malformedMachineLimits.code == evaluation.result.codes.invalidLimits;
    fuelBeforeControl =
      fuelBeforeControl.kind == "resource-exhaustion"
      && fuelBeforeControl.dimension == "fuel"
      && fuelBeforeControl.consumed == 0;
    duplicatedThunkFuelRefusal =
      duplicatedRefusal.kind == "resource-exhaustion" && duplicatedRefusal.consumed == 64;
    deepAnnotationStackSafe = deepAnnotation.ok && deepAnnotation.nodes == 65;
    deepLeftApplicationStackSafe = deepApplication.ok && deepApplication.nodes == 65;
    admittedInactiveOperand = inactiveOperand.ok && inactiveOperand.nodes == 3;
    runtimeFailures =
      missingLevel.code == evaluation.result.codes.missingEnvironmentLevel
      && invalidApplication.code == evaluation.result.codes.invalidSemanticValue
      && invalidCell.code == evaluation.result.codes.invalidEnvironmentCell
      && impossibleState.code == evaluation.result.codes.impossibleMachineState
      && unknownTerm.code == evaluation.result.codes.unknownTerm;
    restoredGenerationBoundaries =
      builtins.all (x: x.code == evaluation.result.codes.staleSemanticGeneration)
        (
          [
            staleEnvironment
            staleValue
            staleCell
            staleClosureValue
            staleTerminal
            staleArgument
          ]
          ++ staleFrames
        );
    projectionClosureGeneration =
      builtins.all (p: !p.ok && p.failure.code == evaluation.result.codes.staleSemanticGeneration) [
        projectionStaleTopLevel
        projectionStaleCell
        projectionStaleContainedValue
        projectionStaleThunkEnvironment
      ]
      && builtins.all (
        x:
        let
          p = projection.project { value = x; };
        in
        !p.ok && p.failure.code == evaluation.result.codes.staleSemanticGeneration
      ) staleProjectionValues;
    neutralSpineCountValidation =
      projectedMixed.ok
      && projectedMixed.value.spineCount == 3
      &&
        map (x: x.kind) projectedMixed.value.spine == [
          "first-projection"
          "second-projection"
          "empty-elimination"
        ]
      && (projection.project { value = semantic.neutral 0; }).value.spineCount == 0
      && (projection.project { value = oneNeutral; }).value.spineCount == 1
      && builtins.all (x: !(projection.project { value = x; }).ok) [
        (badCount (-1))
        (badCount 1.5)
        (badCount 1)
        tooSmallCount
      ];
    boundedProjectionRefusal =
      !projectionRefusal.ok && projectionRefusal.failure.kind == "resource-exhaustion";
    admittedForcingMatrix =
      builtins.all agrees (builtins.attrValues forcingRuns)
      && forcingRuns.firstOnly.machine.nodes == 3
      && forcingRuns.secondOnly.machine.nodes == 3
      && forcingRuns.piInactive.machine.nodes == 1
      && forcingRuns.sigmaInactive.machine.nodes == 1
      && forcingRuns.sumInactive.machine.nodes == 1
      && forcingRuns.identityInactive.machine.nodes == 1
      && forcingRuns.reflInactive.machine.nodes == 1
      && unrelatedEnvironment.ok;
    projectionSensitivity = projectionValueSensitivity && projectionTraceSensitivity;
    independentEvaluatorAuthority =
      direct.authority.termKinds == admittedKinds
      && machine.authority.termKinds == admittedKinds
      && direct.authority.eliminatorKinds == eliminatorKinds
      && machine.authority.eliminatorKinds == eliminatorKinds
      && !(contains "machine.nix" directSource)
      && !(contains "direct.nix" machineSource)
      && contains "./construct.nix" evaluationDefaultSource
      && contains "./direct.nix" evaluationConstructSource
      && contains "./machine.nix" evaluationConstructSource
      && contains "termHandlers" directSource
      && contains "eliminatorHandlers" directSource
      && contains "termHandlers" machineSource
      && contains "eliminatorHandlers" machineSource
      && contains "frameHandlers" machineSource
      && contains "representation.extendNeutral" directSource
      && contains "representation.extendNeutral" machineSource
      && builtins.all (
        source: !(contains "termHandlers" source) && !(contains "eliminatorHandlers" source)
      ) sharedSources
      &&
        builtins.attrNames language == [
          "boundary"
          "generation"
          "syntax"
        ];
    existingLogismosStackOwner =
      contains "../logismos/stack.nix" machineSource
      && !(contains "inherit value rest" machineSource)
      && !(contains "internal/worklist" machineSource);
    admittedAnnotationErasure =
      agrees annotationA
      && agrees annotationB
      && projection.equal {
        left = annotationA.machine.value;
        right = annotationB.machine.value;
      }
      && semanticKinds annotationA.machine.trace == semanticKinds annotationB.machine.trace
      &&
        semanticKinds annotationA.machine.trace == [
          "charge"
          "annotation-erased"
          "charge"
          "lookup"
        ];
    claimTableComplete = builtins.all (names: builtins.all (name: builtins.hasAttr name cases) names) (
      builtins.attrValues claimCases
    );
    beta = agrees beta && beta.machine.value.kind == "neutral";
    canonicalTypes = builtins.all agrees [
      piValue
      sigmaValue
      sumValue
      identityValue
    ];
    canonicalIntroductions =
      builtins.all agrees [
        lambdaValue
        pairValue
        leftValue
        rightValue
        unitValue
        reflValue
      ]
      && lambdaValue.machine.value.kind == "closure"
      && pairValue.machine.value.kind == "pair"
      && leftValue.machine.value.kind == "left-injection"
      && rightValue.machine.value.kind == "right-injection"
      && unitValue.machine.value.kind == "unit"
      && reflValue.machine.value.kind == "refl";
    projections =
      agrees first
      && agrees second
      && first.machine.value.kind == "neutral"
      && second.machine.value.kind == "neutral";
    sumComputations = agrees leftCase && agrees rightCase;
    unitComputation = agrees unitCase;
    jReflComputation = agrees jRefl && jRefl.machine.value.kind == "neutral";
    neutralEliminations = builtins.all agrees [
      neutralApplication
      neutralFirst
      neutralSecond
      neutralCase
      neutralUnit
      emptyNeutral
      neutralJ
    ];
    neutralSpinesNewestFirst =
      projectedSpine.ok
      && projectedSpine.value.spineCount == 1
      && builtins.length projectedSpine.value.spine == 1;
    derivedFixtures = builtins.all agrees derived;
    evaluationSchemaOwned =
      builtins.attrNames evaluation.schema.valueFields
      == builtins.attrNames (import ../../language/evaluation/schema.nix).valueFields;
    generations =
      evaluation.representation.generation == "axiom-evaluation-2"
      && r.generation == "axiom-core-syntax-2";
    limits =
      evaluation.result.limits == {
        nodes = 256;
        depth = 64;
        fuel = 4096;
      };
  };
  failing = builtins.filter (name: !cases.${name}) (builtins.attrNames cases);
in
{
  inherit cases claimCases;
  ok =
    if failing == [ ] then
      true
    else
      throw "axiom evaluation tests FAILED: ${builtins.concatStringsSep ", " failing}";
}
