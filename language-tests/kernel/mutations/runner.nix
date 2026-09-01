let
  graphs = import ../observed-graph.nix;
  registry = import ./registry.nix;
  control = graphs.silent { };
  r = control.core.public.representation;
  contextOf = graph: entries: graph.kernel.public.checkContext { inherit entries; };
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
  };
  probes = {
    "kernel-budget-comparison-charge-canary" = chargeObservation;
    "kernel-conversion-dependent-sigma-witness-canary" = dependentSigmaObservation;
    "kernel-conversion-extensional-pi-resource-canary" = extensionalPiObservation;
    "kernel-conversion-identity-pointwise-canary" = identityPointwiseObservation;
  };
  execute =
    entry:
    let
      selected = registry.byName.${entry.name};
      mutated = graphs.silent (
        if selected.seam == "budget" then
          { budgetFactory = selected.factory; }
        else
          { relationFactory = selected.factory; }
      );
      selectedFactory = selected.factory.identity == entry.name;
      installed =
        if selected.seam == "budget" then
          mutated.kernel.wiring.budget == entry.name
        else
          mutated.logismos.wiring.relation == entry.name;
      controlProduction =
        control.kernel.wiring.budget == "production" && control.logismos.wiring.relation == "production";
      probe = probes.${entry.installationProbe} or null;
      killingCase = cases.${entry.killingTest} or null;
      resolved = probe != null && killingCase != null;
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
    mutationMalformedFactoryRejected = !malformedFactory.success;
  };
}
