{
  lib,
  inputs,
}:
let
  frozenLegacyNames = [
    "canonical"
    "identity"
    "phases"
    "registry"
    "requirements"
    "schema"
    "tagged"
    "validation"
  ];
  namesOf = axiom: builtins.attrNames axiom;

  directLegacy = import ../src { inherit lib; };
  flakeLegacy = inputs.self.lib.axiom { inherit lib; };
  directLanguage = import ../language;
  flakeLanguage = inputs.self.lib.axiomLanguage;
  hostBoundary = import ./host-boundary { language = directLanguage; };
  coreSyntax = import ./core-syntax { language = directLanguage; };
  evaluation = import ./evaluation { language = directLanguage; };
  levels = import ./levels { core = import ../language/core; };
  ruleFamilies = import ./rule-families { core = import ../language/core; };
  kernel = import ./kernel { language = directLanguage; };

  isolatedLegacyRoot = builtins.path {
    path = ../src;
    name = "axiom-isolated-legacy";
  };
  isolatedLanguageRoot = builtins.path {
    path = ../language;
    name = "axiom-isolated-language";
  };
  isolatedLegacy = import isolatedLegacyRoot { inherit lib; };
  isolatedLanguage = import isolatedLanguageRoot;

  newToLegacyFixture = ./fixtures/new-to-legacy;
  legacyToNewFixture = ./fixtures/legacy-to-new;
  newToLegacyControl = import ./fixtures/new-to-legacy/language-source;
  legacyToNewControl = import ./fixtures/legacy-to-new/legacy-source;
  newToLegacyIsolatedRoot = builtins.path {
    path = newToLegacyFixture;
    name = "axiom-new-to-legacy-negative";
    filter =
      path: _type:
      let
        relative = lib.removePrefix "${toString newToLegacyFixture}/" (toString path);
      in
      path == newToLegacyFixture
      || relative == "language-source"
      || lib.hasPrefix "language-source/" relative;
  };
  legacyToNewIsolatedRoot = builtins.path {
    path = legacyToNewFixture;
    name = "axiom-legacy-to-new-negative";
    filter =
      path: _type:
      let
        relative = lib.removePrefix "${toString legacyToNewFixture}/" (toString path);
      in
      path == legacyToNewFixture
      || relative == "legacy-source"
      || lib.hasPrefix "legacy-source/" relative;
  };
  newToLegacyIsolated = builtins.tryEval (import "${newToLegacyIsolatedRoot}/language-source");
  legacyToNewIsolated = builtins.tryEval (import "${legacyToNewIsolatedRoot}/legacy-source");

  repositoryRoot = toString ../.;
  comparison = builtins.path {
    path = ../.;
    name = "axiom-without-language";
    filter =
      path: _type:
      let
        relative = lib.removePrefix "${repositoryRoot}/" (toString path);
      in
      relative == repositoryRoot
      || relative == "flake.nix"
      || relative == "flake.lock"
      || relative == "formatter.nix"
      || relative == "src"
      || lib.hasPrefix "src/" relative
      || relative == "tests"
      || lib.hasPrefix "tests/" relative;
  };
  comparisonDirect = import "${comparison}/src" { inherit lib; };
  comparisonSuite = import "${comparison}/tests" { inherit lib; };
  comparisonInputs = inputs // {
    self = comparisonOutputs;
  };
  comparisonOutputs = (import "${comparison}/flake.nix").outputs comparisonInputs;
  comparisonFlake = comparisonOutputs.lib.axiom { inherit lib; };

  evidence = {
    ordinaryLegacy = (import ../tests { inherit lib; }).ok;
    hostBoundary = hostBoundary.ok;
    coreSyntax = coreSyntax.ok;
    evaluation = evaluation.ok;
    levels = levels.ok;
    ruleFamilies = ruleFamilies.ok;
    kernel = kernel.ok;
    newLineIndependent =
      directLanguage.generation == "axiom-language-1" && flakeLanguage.generation == "axiom-language-1";
    directLegacySurface = namesOf directLegacy == frozenLegacyNames;
    flakeLegacySurface = namesOf flakeLegacy == frozenLegacyNames;
    isolatedLegacyProduction = namesOf isolatedLegacy == frozenLegacyNames;
    isolatedLanguageProduction =
      builtins.attrNames isolatedLanguage == [
        "boundary"
        "generation"
        "syntax"
      ];
    publicLanguageSurface =
      builtins.attrNames directLanguage == [
        "boundary"
        "generation"
        "syntax"
      ];
    publicSyntaxSurface =
      builtins.attrNames directLanguage.syntax == [
        "generation"
        "limits"
        "validate"
      ];
    noPublicCoreAuthority =
      builtins.all
        (name: !(builtins.hasAttr name directLanguage) && !(builtins.hasAttr name directLanguage.syntax))
        [
          "admitted"
          "checked"
          "constructors"
          "core"
          "evaluate"
          "infer"
          "proof"
          "term"
          "type"
        ];
    newToLegacyControl = newToLegacyControl == "legacy-sentinel";
    newToLegacyRejected = !newToLegacyIsolated.success;
    legacyToNewControl = legacyToNewControl == "language-sentinel";
    legacyToNewRejected = !legacyToNewIsolated.success;
    deletionDirect = namesOf comparisonDirect == frozenLegacyNames;
    deletionFlake = namesOf comparisonFlake == frozenLegacyNames;
    deletionSuite = comparisonSuite.ok;
  };
  failed = builtins.attrNames (lib.filterAttrs (_name: pass: !pass) evidence);
  ok =
    if failed == [ ] then
      true
    else
      throw "axiom language foundation tests FAILED: ${lib.concatStringsSep ", " failed}";
in
{
  inherit evidence ok;
}
