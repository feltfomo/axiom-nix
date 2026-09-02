let
  graphs = import ../observed-graph.nix;
  registry = import ./registry.nix;
  control = graphs.silent { };
  r = control.core.public.representation;
  contextOf = graph: entries: graph.kernel.public.checkContext { inherit entries; };
  transitionFixture =
    graph:
    let
      sem = graph.evaluation.public.representation;
      computation = graph.logismos.public.computation;
      transition = graph.kernel.components.neutralTransition;
      budget = graph.kernel.components.budget;
      result = graph.kernel.components.result;
      initialType = sem.pi (sem.valueCell sem.unitType) (
        sem.closure (sem.initialEnvironment 0) r.unitType
      );
      contextValue = (contextOf graph [ (r.envelope 0 (r.pi r.unitType r.unitType) [ ]) ]).context;
      application = sem.spineItem {
        kind = "application";
        argument = sem.valueCell sem.unit;
      };
      unitElimination = sem.spineItem {
        kind = "unit-elimination";
        motive = sem.closure (sem.initialEnvironment 0) (
          r.identityType r.unitType (r.variable 0) (r.variable 0)
        );
        case = sem.valueCell (sem.refl (sem.valueCell sem.unit));
      };
      limits = (budget.merge { }).value;
      runReplay =
        {
          initial,
          spine,
        }:
        let
          spineCount = builtins.length spine;
        in
        computation.run {
          computation = transition.replay {
            judgment = "conversion";
            inherit
              limits
              contextValue
              spine
              spineCount
              ;
            ctx = contextValue;
            initial = {
              inherit (initial) type value;
              observer = null;
            };
            inherit (initial) peerValue;
            peerSpine = spine;
            peerSpineCount = spineCount;
            budgetName = "comparison";
            malformed = result.internal "conversion" 1 result.codes.malformedSemantic;
            mismatch = result.failure "conversion" 1 result.codes.mismatch [ ] "convertible" "distinct";
            observe = _descriptor: observer: computation.pure observer;
          };
          reader = {
            judgment = "conversion";
          };
          state = budget.initial;
        };
      oneStep = runReplay {
        initial = {
          type = initialType;
          value = sem.neutral 0;
          peerValue = sem.neutral 0;
        };
        spine = [ application ];
      };
      dependentStep = runReplay {
        initial = {
          inherit (oneStep.value) type value peerValue;
        };
        spine = [ unitElimination ];
      };
      neutral = sem.extendNeutral (sem.extendNeutral (sem.neutral 0) application) unitElimination;
      expectedApplicationSpine = [ application ];
      expectedDependentSpine = [
        unitElimination
        application
      ];
      expectedEnvelope = r.envelope 1 (r.unitElimination (r.application (r.variable 0) r.unit) (
        r.identityType
        r.unitType
        r.unit
        r.unit
      ) (r.refl r.unit)) [ ];
      readback = graph.kernel.public.quote {
        inherit contextValue;
        type = sem.identityType (sem.valueCell sem.unitType) (sem.valueCell neutral) (
          sem.valueCell neutral
        );
        value = neutral;
      };
      applicationExpectedEnvelope = r.envelope 1 (r.application (r.variable 0) r.unit) [ ];
      applicationReadback = graph.kernel.public.quoteType {
        inherit contextValue;
        value = oneStep.value.value;
      };
      conversion = graph.kernel.public.convertTerms {
        inherit contextValue;
        type = sem.identityType (sem.valueCell sem.unitType) (sem.valueCell neutral) (
          sem.valueCell neutral
        );
        left = neutral;
        right = neutral;
      };
    in
    {
      direct =
        if oneStep.kind == "success" then
          {
            ok = true;
            type = oneStep.value.type.kind;
            valueSpine = oneStep.value.value.spine;
            valueSpineCount = oneStep.value.value.spineCount;
            valueSpineExact = oneStep.value.value.spine == expectedApplicationSpine;
            peerSpine = oneStep.value.peerValue.spine;
            peerSpineCount = oneStep.value.peerValue.spineCount;
            peerSpineExact = oneStep.value.peerValue.spine == expectedApplicationSpine;
          }
        else
          {
            ok = false;
            kind = oneStep.failure.kind or null;
            code = oneStep.failure.code or null;
          };
      dependent =
        if dependentStep.kind == "success" then
          {
            ok = true;
            type = dependentStep.value.type.kind;
            valueSpineCount = dependentStep.value.value.spineCount;
            valueSpineExact = dependentStep.value.value.spine == expectedDependentSpine;
            peerSpineCount = dependentStep.value.peerValue.spineCount;
            peerSpineExact = dependentStep.value.peerValue.spine == expectedDependentSpine;
            argumentKeys = builtins.attrNames dependentStep.value.type.left;
            peerArgumentKeys = builtins.attrNames dependentStep.value.type.right;
          }
        else
          {
            ok = false;
            kind = dependentStep.failure.kind or null;
            code = dependentStep.failure.code or null;
          };
      public = {
        readback = summarize readback;
        readbackEnvelope = readback.value or null;
        readbackExpected = expectedEnvelope;
        applicationReadback = summarize applicationReadback;
        applicationReadbackEnvelope = applicationReadback.value or null;
        applicationReadbackExpected = applicationExpectedEnvelope;
        conversion = summarize conversion;
      };
    };
  transitionObservation =
    graph:
    let
      observed = transitionFixture graph;
    in
    {
      directOk = observed.direct.ok;
      directType = observed.direct.type or null;
      valueSpineCount = observed.direct.valueSpineCount or null;
      valueSpineExact = observed.direct.valueSpineExact or false;
      peerSpineCount = observed.direct.peerSpineCount or null;
      peerSpineExact = observed.direct.peerSpineExact or false;
      valueSpineIsList = builtins.isList (observed.direct.valueSpine or null);
      peerSpineIsList = builtins.isList (observed.direct.peerSpine or null);
      valueSpineLength =
        if builtins.isList (observed.direct.valueSpine or null) then
          builtins.length observed.direct.valueSpine
        else
          null;
      peerSpineLength =
        if builtins.isList (observed.direct.peerSpine or null) then
          builtins.length observed.direct.peerSpine
        else
          null;
      dependentOk = observed.dependent.ok;
      dependentType = observed.dependent.type or null;
      dependentValueSpineCount = observed.dependent.valueSpineCount or null;
      dependentValueSpineExact = observed.dependent.valueSpineExact or false;
      dependentPeerSpineCount = observed.dependent.peerSpineCount or null;
      dependentPeerSpineExact = observed.dependent.peerSpineExact or false;
      dependentArgumentKeys = observed.dependent.argumentKeys or [ ];
      dependentPeerArgumentKeys = observed.dependent.peerArgumentKeys or [ ];
      applicationReadbackOk = observed.public.applicationReadback.ok;
      applicationReadbackCode = observed.public.applicationReadback.code or null;
      applicationReadbackExact =
        observed.public.applicationReadbackEnvelope == observed.public.applicationReadbackExpected;
      readbackOk = observed.public.readback.ok;
      readbackCode = observed.public.readback.code or null;
      readbackExact = observed.public.readbackEnvelope == observed.public.readbackExpected;
      conversionOk = observed.public.conversion.ok;
      conversionCode = observed.public.conversion.code or null;
    };
  summarize =
    result:
    if result.ok then
      {
        ok = true;
        inherit (result) resources;
      }
    else
      {
        ok = false;
        kind = result.kind or null;
        code = result.code or null;
        budget = result.budget or null;
        limit = result.limit or null;
        consumed = result.consumed or null;
      };
  chargeObservation =
    graph:
    let
      sem = graph.evaluation.public.representation;
      result = graph.kernel.public.convertTerms {
        contextValue = (contextOf graph [ (r.envelope 0 r.unitType [ ]) ]).context;
        type = sem.unitType;
        left = sem.unit;
        right = sem.unit;
        limits = {
          conversion = 1;
          comparison = 1;
        };
      };
    in
    {
      inherit (result) ok;
      conversion = result.resources.conversion or null;
      comparison = result.resources.comparison or null;
    };
  dependentSigmaObservation =
    graph:
    let
      sem = graph.evaluation.public.representation;
      contextValue = (contextOf graph [ (r.envelope 0 r.unitType [ ]) ]).context;
      dependentCodomain = r.unitElimination (r.variable 0) (r.universe r.levelZero) r.unitType;
      type = sem.sigma (sem.valueCell sem.unitType) (
        sem.closure (sem.initialEnvironment 0) dependentCodomain
      );
      result = graph.kernel.public.convertTerms {
        inherit contextValue type;
        left = sem.pair (sem.valueCell sem.unit) (sem.valueCell sem.unit);
        right = sem.pair (sem.valueCell (sem.neutral 0)) (sem.valueCell sem.unit);
      };
    in
    summarize result;
  extensionalPiObservation =
    graph:
    let
      sem = graph.evaluation.public.representation;
      type = sem.pi (sem.valueCell sem.unitType) (sem.closure (sem.initialEnvironment 0) r.unitType);
      function = sem.closure (sem.initialEnvironment 0) r.unit;
      result = graph.kernel.public.convertTerms {
        contextValue = (contextOf graph [ ]).context;
        inherit type;
        left = function;
        right = function;
        limits = {
          conversion = 2;
          comparison = 2;
          context = 1;
          readback = 4;
          depth = 1;
        };
      };
    in
    summarize result;
  identityPointwiseObservation =
    graph:
    let
      sem = graph.evaluation.public.representation;
      carrier = sem.valueCell (sem.universe graph.core.public.levels.zero);
      source = sem.valueCell sem.unitType;
      result = graph.kernel.public.convertTypes {
        contextValue = (contextOf graph [ ]).context;
        left = sem.identityType carrier source (sem.valueCell sem.unitType);
        right = sem.identityType carrier source (sem.valueCell sem.emptyType);
      };
    in
    summarize result;
  cases = {
    "language.kernel.test conversionResourceExact" = {
      observe = chargeObservation;
      predicate =
        observation:
        observation == {
          ok = true;
          conversion = 1;
          comparison = 1;
        };
    };
    "language.kernel.test dependentSigmaCodomainWitness" = {
      observe = dependentSigmaObservation;
      predicate = observation: observation.ok;
    };
    "language.kernel.test extensionalPiWitnessResourceExact" = {
      observe = extensionalPiObservation;
      predicate = observation: observation.ok;
    };
    "language.kernel.test identityPointwiseTargetComplete" = {
      observe = identityPointwiseObservation;
      predicate = observation: !observation.ok;
    };
    "language.kernel.test transitionDependentSuccessor" = {
      observe = transitionObservation;
      predicate =
        observation:
        observation.directOk
        && observation.directType == "unit-type"
        && observation.valueSpineExact
        && observation.peerSpineExact
        && observation.dependentOk
        && observation.dependentType == "identity-type"
        && observation.dependentValueSpineExact
        && observation.dependentPeerSpineExact
        && observation.readbackOk
        && observation.readbackExact
        && observation.conversionOk;
    };
    "language.kernel.test transitionApplicationExtension" = {
      observe = transitionObservation;
      predicate =
        observation:
        observation.directOk
        && observation.directType == "unit-type"
        && observation.valueSpineExact
        && observation.peerSpineExact
        && observation.applicationReadbackOk
        && observation.applicationReadbackExact
        && observation.dependentOk
        && observation.dependentType == "identity-type"
        && observation.dependentValueSpineExact
        && observation.dependentPeerSpineExact
        && observation.readbackOk
        && observation.readbackExact
        && observation.conversionOk;
    };
  };
  probes = {
    "kernel-budget-comparison-charge-canary" = chargeObservation;
    "kernel-conversion-dependent-sigma-witness-canary" = dependentSigmaObservation;
    "kernel-conversion-extensional-pi-resource-canary" = extensionalPiObservation;
    "kernel-conversion-identity-pointwise-canary" = identityPointwiseObservation;
    "kernel-transition-wrong-advance-canary" = transitionObservation;
    "kernel-transition-drop-argument-canary" = transitionObservation;
  };
  knownSeams = [
    "budget"
    "relation"
    "transition-advance"
  ];
  execute =
    entry:
    let
      selected = registry.byName.${entry.name};
      knownSeam = builtins.elem selected.seam knownSeams;
      mutationArguments =
        if selected.seam == "budget" then
          { budgetFactory = selected.factory; }
        else if selected.seam == "relation" then
          { relationFactory = selected.factory; }
        else if selected.seam == "transition-advance" then
          { advanceFactory = selected.factory; }
        else
          { };
      mutated = if knownSeam then graphs.silent mutationArguments else null;
      selectedFactory = selected.factory.identity == entry.name;
      installed =
        if !knownSeam then
          false
        else if selected.seam == "budget" then
          mutated.kernel.wiring.budget == entry.name
        else if selected.seam == "relation" then
          mutated.logismos.wiring.relation == entry.name
        else
          mutated.kernel.wiring.transitionAdvance == entry.name;
      controlProduction =
        control.kernel.wiring.budget == "production"
        && control.logismos.wiring.relation == "production"
        && control.kernel.wiring.transitionAdvance == "production";
      probe = probes.${entry.installationProbe} or null;
      killingCase = cases.${entry.killingTest} or null;
      resolved = knownSeam && probe != null && killingCase != null;
      controlProbe = if resolved then probe control else { };
      mutatedProbe = if resolved then probe mutated else { };
      probeDistinguishes = resolved && controlProbe != mutatedProbe;
      productionObservation = if resolved then killingCase.observe control else { };
      mutatedObservation = if resolved then killingCase.observe mutated else { };
      productionPasses = resolved && killingCase.predicate productionObservation;
      mutatedPasses = resolved && killingCase.predicate mutatedObservation;
      proven = selectedFactory && installed && controlProduction && probeDistinguishes;
      outcome =
        if !resolved then
          "configuration-failure"
        else if !proven then
          "installation-failure"
        else if !productionPasses then
          "unexpected-failure"
        else if mutatedPasses then
          "survived"
        else
          "kill";
    in
    {
      inherit (entry) name;
      expected = {
        inherit (entry)
          owner
          violatedLaw
          injectedChange
          expectedObservation
          killingTest
          ;
      };
      observed = {
        inherit
          outcome
          resolved
          selectedFactory
          installed
          controlProduction
          probeDistinguishes
          productionPasses
          mutatedPasses
          productionObservation
          ;
        observation = mutatedObservation;
      };
    };
  results = map execute registry.entries;
  outcomes = map (result: result.observed.outcome) results;
  countOf = wanted: builtins.length (builtins.filter (outcome: outcome == wanted) outcomes);
  malformedFactory = builtins.tryEval (
    builtins.seq
      (graphs.silent {
        relationFactory = {
          identity = "malformed";
        };
      }).logismos.components.relation
      true
  );
  malformedAdvanceFactories = [
    { identity = "missing-selector"; }
    {
      identity = "extra-field";
      select = _capabilities: baseAdvance: baseAdvance;
      extra = true;
    }
    {
      identity = 1;
      select = _capabilities: baseAdvance: baseAdvance;
    }
    {
      identity = "non-function-selector";
      select = 1;
    }
    {
      identity = "non-function-result";
      select = _capabilities: _baseAdvance: 1;
    }
  ];
  malformedAdvanceAttempts = map (
    advanceFactory:
    builtins.tryEval (
      builtins.seq (graphs.silent { inherit advanceFactory; }).kernel.components.neutralTransition.advance
        true
    )
  ) malformedAdvanceFactories;
in
{
  inherit results;
  report = {
    inherit results outcomes;
    entries = builtins.length registry.entries;
    kills = countOf "kill";
    survived = countOf "survived";
    installationFailures = countOf "installation-failure";
    unexpectedFailures = countOf "unexpected-failure";
    configurationFailures = countOf "configuration-failure";
  };
  evidence = {
    mutationRegistryExecuted =
      registry.entries != [ ] && builtins.length results == builtins.length registry.entries;
    mutationRegistryExact =
      map (entry: entry.name) registry.entries == [
        "kernel-budget-skip-comparison-charge"
        "logismos-relation-dependent-witness"
        "logismos-relation-extensional-witness"
        "logismos-relation-pointwise-completeness"
        "kernel-transition-wrong-advance"
        "kernel-transition-drop-argument"
      ];
    mutationCasesResolved = builtins.all (result: result.observed.resolved) results;
    mutationInstallationProven = builtins.all (
      result:
      result.observed.selectedFactory
      && result.observed.installed
      && result.observed.controlProduction
      && result.observed.probeDistinguishes
    ) results;
    mutationProductionPredicatePasses = builtins.all (result: result.observed.productionPasses) results;
    mutationKilled = builtins.all (
      result: result.observed.outcome == "kill" && !result.observed.mutatedPasses
    ) results;
    mutationObservationMatchesMetadata = builtins.all (
      result: result.observed.observation == result.expected.expectedObservation
    ) results;
    mutationMetadataSeparate = builtins.all (
      result:
      !builtins.elem "outcome" (builtins.attrNames result.expected)
      && !builtins.elem "expectedObservation" (builtins.attrNames result.observed)
    ) results;
    mutationSeamsClosed = builtins.all (entry: builtins.elem entry.seam knownSeams) registry.entries;
    mutationMalformedFactoryRejected = !malformedFactory.success;
    mutationMalformedAdvanceFactoriesRejected = builtins.all (
      attempt: !attempt.success
    ) malformedAdvanceAttempts;
  };
}
