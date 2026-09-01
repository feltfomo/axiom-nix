# generic runner over the mutation registry. every registered entry is executed,
# so an entry that no longer has a working factory or killing predicate fails the
# harness instead of sitting unreferenced.
let
  graphs = import ../observed-graph.nix;
  registry = import ./registry.nix;
  control = graphs.silent { };
  r = control.core.public.representation;
  sem = control.evaluation.public.representation;
  contextOf = kernel: kernel.checkContext { entries = [ (r.envelope 0 r.unitType [ ]) ]; };
  # the comparison charge law is specified here rather than read back from the
  # registry, so mutation metadata cannot define its own passing condition
  chargeCase =
    kernel: limits:
    kernel.convertTerms {
      contextValue = (contextOf kernel).context;
      type = sem.unitType;
      left = sem.unit;
      right = sem.unit;
      inherit limits;
    };
  # killing tests and installation probes are independent executable cases keyed
  # by the names a registry entry carries, so an entry naming something unknown
  # fails the harness instead of borrowing the case written for another owner
  killingCases = {
    "language.kernel.test conversionResourceExact" = {
      run =
        kernel:
        chargeCase kernel {
          conversion = 1;
          comparison = 1;
        };
      predicate =
        result: result.ok && result.resources.conversion == 1 && result.resources.comparison == 1;
    };
  };
  # a probe is behavioral, so it separates a genuinely installed owner from a
  # construction that merely reports a different identity string
  probeCases = {
    "kernel-budget-comparison-charge-canary" =
      kernel:
      chargeCase kernel {
        conversion = 1;
        comparison = 0;
      };
  };
  execute =
    entry:
    let
      selected = registry.byName.${entry.name};
      mutated = graphs.silent { budgetFactory = selected.factory; };
      mutatedKernel = mutated.kernel.public;
      productionKernel = control.kernel.public;
      selectedFactory = selected.factory.identity == entry.name;
      installed = mutated.kernel.wiring.budget == entry.name;
      controlProduction = control.kernel.wiring.budget == "production";
      probeCase = probeCases.${entry.installationProbe} or null;
      killingCase = killingCases.${entry.killingTest} or null;
      resolved = probeCase != null && killingCase != null;
      probeControl = probeCase productionKernel;
      probeMutated = probeCase mutatedKernel;
      probeDistinguishes = resolved && (!probeControl.ok) && probeMutated.ok;
      productionResult = killingCase.run productionKernel;
      mutatedResult = killingCase.run mutatedKernel;
      productionPasses = resolved && killingCase.predicate productionResult;
      mutatedPasses = resolved && killingCase.predicate mutatedResult;
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
          ;
        observation =
          if resolved then { inherit (mutatedResult.resources) conversion comparison; } else { };
      };
    };
  results = map execute registry.entries;
  outcomes = map (result: result.observed.outcome) results;
  countOf = wanted: builtins.length (builtins.filter (outcome: outcome == wanted) outcomes);
  malformedFactory = builtins.tryEval (
    builtins.seq
      (graphs.silent {
        budgetFactory = {
          identity = "malformed";
        };
      }).kernel.components.budget
      true
  );
in
{
  inherit results;
  # consumed by the host mutation mode, which is red when anything survives
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
    # a named probe or killing test that does not resolve to an executable case
    # is a harness failure rather than a silently reused case
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
