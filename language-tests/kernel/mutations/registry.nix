let
  entries = [
    {
      name = "kernel-budget-skip-comparison-charge";
      owner = "language/kernel/budget.nix";
      violatedLaw = "every conversion comparison consumes one comparison unit";
      injectedChange = "comparison charges return without changing budget state";
      expectedObservation = {
        conversion = 1;
        comparison = 0;
      };
      killingTest = "language.kernel.test conversionResourceExact";
      installationProbe = "kernel-budget-comparison-charge-canary";
      factory = import ./skip-comparison-charge.nix;
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
