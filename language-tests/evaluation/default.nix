{ language }:
let
  core = import ../../language/core;
  evaluation = import ../../language/evaluation { inherit core; };
  decoder = import ../../language/syntax/decode.nix {
    inherit core;
    inherit (language.boundary) result;
  };
  inherit (core) representation operations;
  inherit (evaluation) direct machine projection;
  semantic = evaluation.representation;

  inherit (representation) variable;
  inherit (representation) lambda;
  inherit (representation) application;
  inherit (representation) annotation;
  admitted =
    scope: root: metadata:
    let
      checked = operations.admitted (representation.envelope scope root metadata);
    in
    if checked.ok then checked.value else throw "evaluation fixture failed admission";

  run =
    scope: root:
    let
      envelope = admitted scope root [ ];
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

  identity = lambda (variable 1);
  nonzero = run 2 (variable 1);
  closureCapture = run 2 (lambda (application (variable 0) (variable 2)));
  beta = run 1 (application identity (variable 0));
  nested = run 1 (application (application (lambda (lambda (variable 1))) (variable 0)) (variable 0));
  neutralApplication = run 2 (
    application (variable 1) (lambda (application (variable 2) (variable 2)))
  );
  repeatedThunk = run 1 (application (lambda (application (variable 1) (variable 1))) (variable 0));

  annotationA = run 1 (annotation (variable 0) (lambda (variable 1)));
  annotationB = run 1 (annotation (variable 0) (application (variable 0) (variable 0)));
  kinds = trace: map (event: event.kind) (projection.semanticEvents trace);

  omega = application (lambda (application (variable 0) (variable 0))) (
    lambda (application (variable 0) (variable 0))
  );
  inactiveOperand = machine.evaluate {
    envelope = admitted 1 (application (lambda (variable 0)) omega) [ ];
  };
  neutralWithInactiveSpine = machine.evaluate {
    envelope = admitted 1 (application (variable 0) omega) [ ];
  };

  poison = throw "evaluation poison forced";
  lazyEnvironment = {
    inherit (semantic) generation;
    nextLevel = 2;
    cells = {
      "0" = semantic.valueCell (semantic.neutral 0);
      "1" = semantic.valueCell poison;
    };
  };
  unrelatedCell = direct.runRoot {
    root = variable 0;
    environment = lazyEnvironment;
  };

  publicPoison = decoder.decode {
    inherit (representation) generation;
    scope = 1;
    term = {
      kind = "annotation";
      subject = {
        kind = "variable";
        level = 0;
      };
      annotation = poison;
    };
    metadata = [ ];
  };
  publicMalformed = decoder.decode {
    inherit (representation) generation;
    scope = 0;
    term = {
      kind = "future";
    };
    metadata = [ ];
  };

  metadataRoot = annotation (variable 0) (lambda (variable 1));
  metadataA = admitted 1 metadataRoot [
    {
      path = [ ];
      name = "first";
      location = [ "a" ];
    }
  ];
  metadataB = admitted 1 metadataRoot [
    {
      path = [ ];
      name = "second";
      location = [
        "b"
        2
      ];
    }
  ];
  metadataRunA = {
    direct = direct.evaluate { envelope = metadataA; };
    machine = machine.evaluate { envelope = metadataA; };
  };
  metadataRunB = {
    direct = direct.evaluate { envelope = metadataB; };
    machine = machine.evaluate { envelope = metadataB; };
  };

  modulo = left: right: left - (builtins.div left right) * right;
  generatedTerm =
    scope: seed:
    let
      first = modulo seed scope;
      second = modulo (seed + 1) scope;
      body = application (variable first) (variable scope);
    in
    annotation (application (lambda body) (variable second)) (
      application (variable second) (variable first)
    );
  generatedScopes = [
    1
    2
    3
    4
    5
  ];
  generatedSeeds = [
    0
    1
    2
    3
    4
    5
    6
    7
  ];
  generated = builtins.concatLists (
    map (scope: map (seed: run scope (generatedTerm scope seed)) generatedSeeds) generatedScopes
  );

  nestAnnotations =
    count: tail:
    if count == 0 then tail else annotation (nestAnnotations (count - 1) tail) (variable 0);
  leftApplications =
    count: term:
    if count == 0 then term else application (leftApplications (count - 1) term) (variable 0);

  exactNodeEnvelope = admitted 1 (nestAnnotations 7 (variable 0)) [ ];
  overNodeEnvelope = admitted 1 (nestAnnotations 8 (variable 0)) [ ];
  exactNode = machine.evaluate {
    envelope = exactNodeEnvelope;
    limits.nodes = 8;
  };
  overNode = machine.evaluate {
    envelope = overNodeEnvelope;
    limits.nodes = 8;
  };
  exactDepth = machine.evaluate {
    envelope = admitted 1 (nestAnnotations 4 (variable 0)) [ ];
    limits.depth = 4;
  };
  overDepth = machine.evaluate {
    envelope = admitted 1 (nestAnnotations 5 (variable 0)) [ ];
    limits.depth = 4;
  };
  fuelProbe = machine.evaluate { envelope = admitted 1 (application identity (variable 0)) [ ]; };
  exactFuel = machine.evaluate {
    envelope = admitted 1 (application identity (variable 0)) [ ];
    limits.fuel = fuelProbe.fuel;
  };
  overFuel = machine.evaluate {
    envelope = admitted 1 (application identity (variable 0)) [ ];
    limits.fuel = fuelProbe.fuel - 1;
  };
  duplicatedRefusal = machine.evaluate {
    envelope = admitted 0 omega [ ];
    limits.fuel = 64;
  };

  deepAnnotation = machine.evaluate {
    envelope = admitted 1 (nestAnnotations 64 (variable 0)) [ ];
  };
  deepApplication = machine.evaluate {
    envelope = admitted 1 (leftApplications 64 (variable 0)) [ ];
  };

  missingEnvironment = direct.runRoot {
    root = variable 0;
    environment = semantic.initialEnvironment 0;
  };
  unknownTerm = direct.runRoot {
    root = {
      kind = "future";
    };
    environment = semantic.initialEnvironment 0;
  };
  invalidApplication = direct.runRoot {
    root = application (variable 0) (variable 0);
    environment = {
      inherit (semantic) generation;
      nextLevel = 1;
      cells."0" = semantic.valueCell ((semantic.neutral 0) // { kind = "future"; });
    };
  };
  impossibleState = machine.runState {
    state = {
      status = "running";
      control = {
        kind = "future";
      };
      frames = [ ];
      nodes = 0;
      fuel = 0;
      trace = [ ];
      terminal = null;
      failure = null;
    };
  };
  invalidCell = direct.runRoot {
    root = variable 0;
    environment = {
      inherit (semantic) generation;
      nextLevel = 1;
      cells."0" = {
        inherit (semantic) generation;
        kind = "future";
      };
    };
  };
  staleEnvironment = direct.runRoot {
    root = variable 0;
    environment = (semantic.initialEnvironment 1) // {
      generation = "axiom-evaluation-0";
    };
  };
  missingEnvironmentGeneration = direct.runRoot {
    root = variable 0;
    environment = builtins.removeAttrs (semantic.initialEnvironment 1) [ "generation" ];
  };
  staleCell = direct.runRoot {
    root = variable 0;
    environment = (semantic.initialEnvironment 1) // {
      cells."0" = (semantic.valueCell (semantic.neutral 0)) // {
        generation = "axiom-evaluation-0";
      };
    };
  };
  staleClosure = direct.runRoot {
    root = application (variable 0) (variable 0);
    environment = (semantic.initialEnvironment 1) // {
      cells."0" = semantic.valueCell (
        (semantic.closure (semantic.initialEnvironment 0) (variable 0))
        // {
          generation = "axiom-evaluation-0";
        }
      );
    };
  };
  staleNeutral = direct.runRoot {
    root = application (variable 0) (variable 0);
    environment = (semantic.initialEnvironment 1) // {
      cells."0" = semantic.valueCell ((semantic.neutral 0) // { generation = "axiom-evaluation-0"; });
    };
  };

  staleValueEnvironment = (semantic.initialEnvironment 1) // {
    cells."0" = semantic.valueCell ((semantic.neutral 0) // { generation = "axiom-evaluation-0"; });
  };
  staleValueDirect = direct.runRoot {
    root = variable 0;
    environment = staleValueEnvironment;
  };
  staleValueMachine = machine.runState {
    state = machine.initialState (variable 0) staleValueEnvironment;
  };
  staleClosureValueEnvironment = (semantic.initialEnvironment 1) // {
    cells."0" = semantic.valueCell (
      (semantic.closure (semantic.initialEnvironment 0) (variable 0))
      // {
        generation = "axiom-evaluation-0";
      }
    );
  };
  staleClosureValueDirect = direct.runRoot {
    root = variable 0;
    environment = staleClosureValueEnvironment;
  };
  staleInitial = (semantic.initialEnvironment 1) // {
    generation = "axiom-evaluation-0";
    cells."0" = poison;
  };
  staleInitialDirect = direct.runRoot {
    root = lambda (variable 1);
    environment = staleInitial;
  };
  staleInitialMachine = machine.runState {
    state = machine.initialState (lambda (variable 1)) staleInitial;
  };
  currentClosureStaleEnvironment = semantic.closure staleInitial (variable 0);
  capturedEnvironmentSource = (semantic.initialEnvironment 1) // {
    cells."0" = semantic.valueCell currentClosureStaleEnvironment;
  };
  staleCapturedDirect = direct.runRoot {
    root = application (variable 0) (variable 0);
    environment = capturedEnvironmentSource;
  };
  staleCapturedMachine = machine.runState {
    state = machine.initialState (application (variable 0) (variable 0)) capturedEnvironmentSource;
  };
  staleFrame = machine.runState {
    state = {
      status = "running";
      control = {
        kind = "return";
        value = semantic.closure (semantic.initialEnvironment 0) (variable 0);
      };
      frames = [
        {
          kind = "apply-operator";
          argument = (semantic.thunkCell (semantic.initialEnvironment 0) (variable 0)) // {
            generation = "axiom-evaluation-0";
          };
          depth = 0;
        }
      ];
      nodes = 0;
      fuel = 0;
      trace = [ ];
      terminal = null;
      failure = null;
    };
  };
  staleTerminal = machine.runState {
    state = {
      status = "running";
      control = {
        kind = "return";
        value = (semantic.neutral 0) // {
          generation = "axiom-evaluation-0";
        };
      };
      frames = [ ];
      nodes = 0;
      fuel = 0;
      trace = [ ];
      terminal = null;
      failure = null;
    };
  };
  projectionStaleNeutral = projection.project {
    value = (semantic.neutral 0) // {
      generation = "axiom-evaluation-0";
    };
  };
  projectionStaleClosure = projection.project {
    value = (semantic.closure (semantic.initialEnvironment 0) (variable 0)) // {
      generation = "axiom-evaluation-0";
    };
  };
  projectionStaleCell = projection.project {
    value = semantic.closure (
      (semantic.initialEnvironment 1)
      // {
        cells."0" = (semantic.valueCell (semantic.neutral 0)) // {
          generation = "axiom-evaluation-0";
        };
      }
    ) (variable 0);
  };
  projectionStaleEnvironment = projection.project {
    value = semantic.closure staleInitial (variable 0);
  };

  annotationKindsA = kinds annotationA.machine.trace;
  annotationKindsB = kinds annotationB.machine.trace;
  cases = {
    variableAtNonzeroScope = agrees nonzero && nonzero.machine.value.head.level == 1;
    closureCapture = agrees closureCapture && closureCapture.machine.value.environment.nextLevel == 2;
    betaApplication = agrees beta && beta.machine.value.head.level == 0;
    nestedClosureApplication = agrees nested && nested.machine.value.head.level == 0;
    repeatedBoundThunk = agrees repeatedThunk;
    openNeutralApplication =
      agrees neutralApplication
      && neutralApplication.machine.value.head.level == 1
      && builtins.length neutralApplication.machine.value.spine == 1;
    generatedAgreement = builtins.all agrees generated;
    annotationErasure =
      agrees annotationA
      && agrees annotationB
      && projection.equal {
        left = annotationA.machine.value;
        right = annotationB.machine.value;
      }
      && projection.traceEqual annotationA.machine.trace annotationB.machine.trace
      && annotationA.machine.nodes == 2
      && annotationB.machine.nodes == 2
      && annotationKindsA == annotationKindsB
      &&
        annotationKindsA == [
          "charge"
          "annotation-erased"
          "charge"
          "lookup"
        ];
    publicPoisonRejected = publicPoison.kind == "host-failure";
    publicMalformedRejected = publicMalformed.kind != "success";
    inactiveOperandUnforced =
      inactiveOperand.ok
      && inactiveOperand.nodes == 3
      && !(builtins.elem "force" (kinds inactiveOperand.trace));
    neutralSpineArgumentUnforced =
      neutralWithInactiveSpine.ok
      && neutralWithInactiveSpine.nodes == 2
      && !(builtins.elem "force" (kinds neutralWithInactiveSpine.trace));
    unrelatedEnvironmentCellUnforced =
      unrelatedCell.ok && unrelatedCell.value.kind == "neutral" && unrelatedCell.value.head.level == 0;
    metadataIrrelevant =
      projection.equal {
        left = metadataRunA.direct.value;
        right = metadataRunB.direct.value;
      }
      && projection.traceEqual metadataRunA.direct.trace metadataRunB.direct.trace
      && projection.equal {
        left = metadataRunA.machine.value;
        right = metadataRunB.machine.value;
      }
      && projection.traceEqual metadataRunA.machine.trace metadataRunB.machine.trace;
    exactNodeBoundary = exactNode.ok && exactNode.nodes == 8;
    oneOverNodeBoundary =
      overNode.kind == "resource-exhaustion" && overNode.dimension == "nodes" && overNode.consumed == 8;
    exactDepthBoundary = exactDepth.ok && exactDepth.nodes == 5;
    oneOverDepthBoundary =
      overDepth.kind == "resource-exhaustion"
      && overDepth.dimension == "depth"
      && overDepth.consumed == 5;
    exactFuelBoundary = exactFuel.ok && exactFuel.fuel == fuelProbe.fuel;
    oneOverFuelBoundary =
      overFuel.kind == "resource-exhaustion"
      && overFuel.dimension == "fuel"
      && overFuel.consumed == fuelProbe.fuel - 1;
    duplicatedThunkFuelRefusal =
      duplicatedRefusal.kind == "resource-exhaustion"
      && duplicatedRefusal.dimension == "fuel"
      && duplicatedRefusal.consumed == 64;
    deepAnnotationStackSafe = deepAnnotation.ok && deepAnnotation.nodes == 65;
    deepLeftApplicationStackSafe = deepApplication.ok && deepApplication.nodes == 65;
    missingLevelCode = missingEnvironment.code == evaluation.result.codes.missingEnvironmentLevel;
    unknownTermCode = unknownTerm.code == evaluation.result.codes.unknownTerm;
    invalidValueCode = invalidApplication.code == evaluation.result.codes.invalidSemanticValue;
    impossibleStateCode = impossibleState.code == evaluation.result.codes.impossibleMachineState;
    invalidCellCode = invalidCell.code == evaluation.result.codes.invalidEnvironmentCell;
    staleValuesRejectedAtResult =
      builtins.all (value: value.code == evaluation.result.codes.staleSemanticGeneration)
        [
          staleValueDirect
          staleValueMachine
          staleClosureValueDirect
        ];
    staleInitialEnvironmentsRejected =
      staleInitialDirect.code == evaluation.result.codes.staleSemanticGeneration
      && staleInitialMachine.code == evaluation.result.codes.staleSemanticGeneration;
    staleCapturedEnvironmentsRejected =
      staleCapturedDirect.code == evaluation.result.codes.staleSemanticGeneration
      && staleCapturedMachine.code == evaluation.result.codes.staleSemanticGeneration;
    staleFrameArgumentRejected = staleFrame.code == evaluation.result.codes.staleSemanticGeneration;
    staleTerminalRejected =
      staleTerminal.code == evaluation.result.codes.staleSemanticGeneration && !(staleTerminal ? value);
    staleProjectionRejected =
      builtins.all (value: value.failure.code == evaluation.result.codes.staleSemanticGeneration)
        [
          projectionStaleNeutral
          projectionStaleClosure
          projectionStaleCell
          projectionStaleEnvironment
        ];
    semanticGenerationFrozen = semantic.generation == "axiom-evaluation-1";
    representationsStamped =
      (semantic.initialEnvironment 0).generation == semantic.generation
      && (semantic.valueCell (semantic.neutral 0)).generation == semantic.generation
      &&
        (semantic.thunkCell (semantic.initialEnvironment 0) (variable 0)).generation == semantic.generation
      && (semantic.closure (semantic.initialEnvironment 0) (variable 0)).generation == semantic.generation
      && (semantic.neutral 0).generation == semantic.generation;
    staleGenerationsRejected =
      builtins.all (value: value.code == evaluation.result.codes.staleSemanticGeneration)
        [
          staleEnvironment
          missingEnvironmentGeneration
          staleCell
          staleClosure
          staleNeutral
        ];
    limitsFrozen =
      evaluation.result.limits == {
        nodes = 256;
        depth = 64;
        fuel = 4096;
      };
    codesFrozen =
      evaluation.result.codes == {
        missingEnvironmentLevel = "AXIOM-EVAL-001";
        unknownTerm = "AXIOM-EVAL-002";
        invalidSemanticValue = "AXIOM-EVAL-003";
        impossibleMachineState = "AXIOM-EVAL-004";
        invalidEnvironmentCell = "AXIOM-EVAL-005";
        staleSemanticGeneration = "AXIOM-EVAL-006";
      };
  };
  failing = builtins.attrNames (
    builtins.removeAttrs cases (builtins.filter (name: cases.${name}) (builtins.attrNames cases))
  );
  ok =
    if failing == [ ] then
      true
    else
      throw "axiom evaluation tests FAILED: ${builtins.concatStringsSep ", " failing}";
  evidence = {
    generatedCorpus = builtins.length generated;
    generatedRule = "five scopes by eight seeds";
    exactNodes = exactNode.nodes;
    overNodes = overNode.consumed;
    exactDepthNodes = exactDepth.nodes;
    overDepthNodes = overDepth.consumed;
    exactFuel = fuelProbe.fuel;
    duplicatedFuel = duplicatedRefusal.consumed;
    deepAnnotationNodes = deepAnnotation.nodes;
    deepApplicationNodes = deepApplication.nodes;
    inherit annotationKindsA annotationKindsB;
  };
in
{
  inherit cases evidence ok;
}
