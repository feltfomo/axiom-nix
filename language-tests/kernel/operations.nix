# operation fixtures for the pre-rewrite baseline. semantic expectations here are
# closed forms in the ladder depth, so a rung that stops depending on a nested
# layer breaks the expectation instead of being absorbed by a copied number.
let
  graphs = import ./observed-graph.nix;
  observation = import ../../language/internal/operation-observer.nix;
  productionCore = import ../../language/core;
  productionEvaluation = import ../../language/evaluation { core = productionCore; };
  productionLogismos = import ../../language/logismos;
  productionKernel = import ../../language/kernel { core = productionCore; };
  silent = graphs.silent { };
  quiet = graphs.observed { hook = _event: true; };
  ladder = [
    3
    5
    11
    23
    37
  ];
  syntaxOf = graph: graph.core.public.representation;
  piTower = r: n: if n <= 0 then r.unitType else r.pi r.unitType (piTower r (n - 1));
  sigmaTower = r: n: if n <= 1 then r.unitType else r.sigma r.unitType (sigmaTower r (n - 1));
  appliedSpine =
    r: n:
    builtins.foldl' (term: _: r.application term r.unit) (r.variable 0) (builtins.genList (i: i) n);
  projectedSpine =
    r: n:
    r.firstProjection (
      builtins.foldl' (term: _: r.secondProjection term) (r.variable 0) (builtins.genList (i: i) (n - 2))
    );
  legs =
    graph: n:
    let
      r = syntaxOf graph;
      kernel = graph.kernel.public;
      contextOf = syntax: kernel.checkContext { entries = [ (r.envelope 0 syntax [ ]) ]; };
      unitContext = contextOf (piTower r n);
      unitInference = kernel.infer {
        contextValue = unitContext.context;
        envelope = r.envelope 1 (appliedSpine r n) [ ];
      };
      towerContext = contextOf (sigmaTower r n);
      towerVariable = kernel.infer {
        contextValue = towerContext.context;
        envelope = r.envelope 1 (r.variable 0) [ ];
      };
      towerProjection = kernel.infer {
        contextValue = towerContext.context;
        envelope = r.envelope 1 (projectedSpine r n) [ ];
      };
      readback = kernel.quoteType {
        contextValue = towerContext.context;
        value = towerVariable.type;
      };
      independentContext = contextOf (sigmaTower r n);
      independentVariable = kernel.infer {
        contextValue = independentContext.context;
        envelope = r.envelope 1 (r.variable 0) [ ];
      };
      conversion = kernel.convertTypes {
        contextValue = towerContext.context;
        left = towerVariable.type;
        right = independentVariable.type;
      };
      oracle = kernel.oracle {
        contextValue = towerContext.context;
        inherit (towerProjection) type;
        left = towerProjection.value;
        right = towerProjection.value;
      };
      canonical = readback.value.root or readback.value;
    in
    {
      inherit
        unitContext
        unitInference
        towerContext
        towerVariable
        towerProjection
        readback
        conversion
        oracle
        canonical
        ;
      depth = n;
      accepted = builtins.all (leg: leg.ok) [
        unitContext
        unitInference
        towerContext
        towerVariable
        towerProjection
        readback
        conversion
        oracle
      ];
      # a skipped tower layer changes this canonical observation, which unit
      # uniqueness would otherwise hide
      canonicalMatches = canonical == sigmaTower r n;
      canonicalDistinguishes = canonical != sigmaTower r (n - 1);
    };
  vector =
    overrides:
    {
      checking = 0;
      comparison = 0;
      context = 0;
      conversion = 0;
      depth = 1;
      output = 0;
      readback = 0;
    }
    // overrides;
  expectations = n: {
    unitContext = vector {
      checking = 2 * n + 1;
      context = n + 1;
    };
    unitInference = vector {
      checking = 2 * n + 1;
      readback = 2 * n;
    };
    towerContext = vector {
      checking = 2 * n - 1;
      context = n;
    };
    towerVariable = vector { checking = 1; };
    towerProjection = vector {
      checking = n;
      readback = 3 * n - 5;
    };
    readback = vector {
      context = n - 1;
      depth = n;
      output = 2 * n - 1;
      readback = 4 * n - 3;
    };
    conversion = vector {
      comparison = 2 * n - 1;
      context = n - 1;
      conversion = 2 * n - 1;
      depth = n;
      readback = 4 * n - 4;
    };
    oracle = vector {
      output = 2;
      readback = 2;
    };
  };
  legNames = [
    "unitContext"
    "unitInference"
    "towerContext"
    "towerVariable"
    "towerProjection"
    "readback"
    "conversion"
    "oracle"
  ];
  measured = map (legs silent) ladder;
  observedMeasured = map (legs quiet) ladder;
  indices = builtins.genList (i: i) (builtins.length ladder);
  exactVectors = builtins.all (
    record:
    let
      expected = expectations record.depth;
    in
    builtins.all (name: record.${name}.resources == expected.${name}) legNames
  ) measured;
  accepted = builtins.all (record: record.accepted) measured;
  canonicalObservations = builtins.all (
    record: record.canonicalMatches && record.canonicalDistinguishes
  ) measured;
  sameRun =
    left: right:
    builtins.all (
      name: left.${name}.ok == right.${name}.ok && left.${name}.resources == right.${name}.resources
    ) legNames
    && left.canonical == right.canonical;
  observedSilentParity = builtins.all (
    index: sameRun (builtins.elemAt measured index) (builtins.elemAt observedMeasured index)
  ) indices;
  productionGraph = {
    core.public = productionCore;
    kernel.public = productionKernel;
  };
  productionParity = sameRun (legs productionGraph 3) (legs quiet 3);
  event = {
    operation = "kernel.conversion.type";
  };
  hostile = observation.observed (_event: throw "hook executed");
  # a whole observed graph whose hook throws as soon as an operation executes
  poisoned = graphs.observed { hook = _event: throw "hook executed"; };
  counting = observation.observed (_event: true);
  rewriting = observation.observed (_event: "hook result");
  refused = value: !(builtins.tryEval (builtins.seq value true)).success;
  traced = frame: graphs.observed { hook = graphs.traceHook frame; };
  legMeasurement =
    run: n: name:
    (legs (traced { inherit run n name; }) n).${name}.ok;
in
{
  inherit
    ladder
    legNames
    measured
    expectations
    ;
  # forced by the host measurement command, which counts the traced events
  measurement = builtins.all (
    n: builtins.all (name: legMeasurement "baseline" n name) legNames
  ) ladder;
  evidence = {
    operationLaddersAccepted = accepted;
    operationVectorsExact = exactVectors;
    operationCanonicalObservation = canonicalObservations;
    operationObservedSilentParity = observedSilentParity;
    operationProductionParity = productionParity;
    observerHookResultDiscarded = (rewriting.emit event 41) + 1 == 42;
    # the outer list returned by emit is forced while its poisoned element is
    # not, so instrumentation cannot reach into a payload it wraps
    observerPayloadUnforced =
      let
        wrapped = builtins.tryEval (builtins.length (counting.emit event [ (throw "payload forced") ]));
      in
      wrapped.success && wrapped.value == 1;
    observerExecutionReachesHook = refused (hostile.emit event 1);
    observerUnknownRejected = refused (counting.emit { operation = "kernel.unknown"; } 1);
    observerMalformedRejected = refused (counting.emit { operation = 1; } 1);
    observerSilentEmitsNothing = observation.silent.emit event 7 == 7;
    # building a real workload under a hook that throws succeeds while forcing
    # the same workload does not, which separates construction from execution
    # rather than import from invocation. the admission leg is used because a
    # conversion can refuse on a judgment mismatch before it executes any
    # observed operation, which would make the forcing side vacuous
    observerConstructionEmitsNothing =
      let
        program = {
          inherit (legs poisoned 3) unitContext;
        };
        constructed = builtins.tryEval (builtins.attrNames program == [ "unitContext" ]);
      in
      constructed.success && constructed.value;
    observerGraphExecutionReachesHook = refused (legs poisoned 3).unitContext.ok;
    observedGraphWiring =
      quiet.observers == [
        "observed"
        "observed"
        "observed"
        "observed"
      ];
    silentGraphWiring =
      silent.observers == [
        "silent"
        "silent"
        "silent"
        "silent"
      ];
    observedGraphGenerations =
      quiet.kernel.wiring.core == quiet.core.public.representation.generation
      && quiet.kernel.wiring.evaluation == quiet.evaluation.public.representation.generation;
    observedGraphBudgetProduction = silent.kernel.wiring.budget == "production";
    observedGraphSurfaceParity =
      builtins.attrNames quiet.kernel.public == builtins.attrNames productionKernel
      && builtins.attrNames quiet.core.public == builtins.attrNames productionCore
      && builtins.attrNames quiet.evaluation.public == builtins.attrNames productionEvaluation
      && builtins.attrNames quiet.logismos.public == builtins.attrNames productionLogismos;
  };
}
