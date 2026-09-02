let
  entries = [
    {
      name = "kernel-budget-skip-comparison-charge";
      owner = "language/kernel/budget.nix";
      violatedLaw = "every conversion comparison consumes one comparison unit";
      injectedChange = "comparison charges return without changing budget state";
      expectedObservation = {
        ok = true;
        conversion = 1;
        comparison = 0;
      };
      killingTest = "language.kernel.test conversionResourceExact";
      installationProbe = "kernel-budget-comparison-charge-canary";
      seam = "budget";
      factory = import ./skip-comparison-charge.nix;
    }
    {
      name = "logismos-relation-dependent-witness";
      owner = "language/logismos/relation.nix";
      violatedLaw = "the dependent relation receives the retained left and right witnesses";
      injectedChange = "the dependent continuation receives the right witness as its first argument";
      expectedObservation = {
        ok = false;
        kind = "internal-failure";
        code = "AXIOM-KERNEL-006";
        budget = null;
        limit = null;
        consumed = null;
      };
      killingTest = "language.kernel.test dependentSigmaCodomainWitness";
      installationProbe = "kernel-conversion-dependent-sigma-witness-canary";
      seam = "relation";
      factory = import ./dependent-witness.nix;
    }
    {
      name = "logismos-relation-extensional-witness";
      owner = "language/logismos/relation.nix";
      violatedLaw = "one retained witness supplies both applications and the codomain";
      injectedChange = "applications and codomain receive separately produced witnesses";
      expectedObservation = {
        ok = false;
        kind = "resource-exhaustion";
        code = "AXIOM-KERNEL-001";
        budget = "context";
        limit = 1;
        consumed = 1;
      };
      killingTest = "language.kernel.test extensionalPiWitnessResourceExact";
      installationProbe = "kernel-conversion-extensional-pi-resource-canary";
      seam = "relation";
      factory = import ./extensional-witness.nix;
    }
    {
      name = "logismos-relation-pointwise-completeness";
      owner = "language/logismos/relation.nix";
      violatedLaw = "pointwise comparison visits every aligned position";
      injectedChange = "the final aligned position is omitted";
      expectedObservation = {
        ok = true;
        resources = {
          checking = 0;
          comparison = 4;
          context = 0;
          conversion = 4;
          depth = 0;
          output = 0;
          readback = 4;
        };
      };
      killingTest = "language.kernel.test identityPointwiseTargetComplete";
      installationProbe = "kernel-conversion-identity-pointwise-canary";
      seam = "relation";
      factory = import ./pointwise-completeness.nix;
    }
    {
      name = "kernel-transition-wrong-advance";
      owner = "language/kernel/neutral-transition.nix";
      violatedLaw = "application advancement applies the codomain to the argument";
      injectedChange = "application advancement retains the incoming pi type";
      expectedObservation = {
        applicationReadbackCode = null;
        applicationReadbackExact = true;
        applicationReadbackOk = true;
        conversionCode = "AXIOM-KERNEL-002";
        conversionOk = false;
        dependentArgumentKeys = [ ];
        dependentOk = false;
        dependentPeerArgumentKeys = [ ];
        dependentPeerSpineCount = null;
        dependentPeerSpineExact = false;
        dependentType = null;
        dependentValueSpineCount = null;
        dependentValueSpineExact = false;
        directOk = true;
        directType = "pi";
        peerSpineCount = 1;
        peerSpineExact = true;
        peerSpineIsList = true;
        peerSpineLength = 1;
        readbackCode = "AXIOM-KERNEL-010";
        readbackExact = false;
        readbackOk = false;
        valueSpineCount = 1;
        valueSpineExact = true;
        valueSpineIsList = true;
        valueSpineLength = 1;
      };
      killingTest = "language.kernel.test transitionDependentSuccessor";
      installationProbe = "kernel-transition-wrong-advance-canary";
      seam = "transition-advance";
      factory = import ./wrong-transition-advance.nix;
    }
    {
      name = "kernel-transition-drop-argument";
      owner = "language/kernel/neutral-transition.nix";
      violatedLaw = "application advancement extends both typed neutrals by the application item";
      injectedChange = "application advancement restores both incoming neutrals";
      expectedObservation = {
        applicationReadbackCode = null;
        applicationReadbackExact = false;
        applicationReadbackOk = true;
        conversionCode = null;
        conversionOk = true;
        dependentArgumentKeys = [
          "environment"
          "generation"
          "kind"
          "term"
        ];
        dependentOk = true;
        dependentPeerArgumentKeys = [
          "environment"
          "generation"
          "kind"
          "term"
        ];
        dependentPeerSpineCount = 1;
        dependentPeerSpineExact = false;
        dependentType = "identity-type";
        dependentValueSpineCount = 1;
        dependentValueSpineExact = false;
        directOk = true;
        directType = "unit-type";
        peerSpineCount = 0;
        peerSpineExact = false;
        peerSpineIsList = true;
        peerSpineLength = 0;
        readbackCode = null;
        readbackExact = true;
        readbackOk = true;
        valueSpineCount = 0;
        valueSpineExact = false;
        valueSpineIsList = true;
        valueSpineLength = 0;
      };
      killingTest = "language.kernel.test transitionApplicationExtension";
      installationProbe = "kernel-transition-drop-argument-canary";
      seam = "transition-advance";
      factory = import ./drop-transition-argument.nix;
    }
  ];
  names = map (entry: entry.name) entries;
  indexed = builtins.listToAttrs (
    map (entry: {
      inherit (entry) name;
      value = entry;
    }) entries
  );
in
if builtins.length names == builtins.length (builtins.attrNames indexed) then
  {
    inherit entries;
    byName = indexed;
  }
else
  throw "duplicate mutation name"
