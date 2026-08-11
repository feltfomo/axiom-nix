{ language }:
let
  core = import ../../language/core;
  decoder = import ../../language/syntax/decode.nix {
    inherit core;
    inherit (language.boundary) result;
  };
  inherit (core) representation operations;
  poison = throw "core syntax poison was forced";

  variable = level: {
    kind = "variable";
    inherit level;
  };
  lambda = body: {
    kind = "lambda";
    inherit body;
  };
  application = function: argument: {
    kind = "application";
    inherit function argument;
  };
  annotation = subject: annotation: {
    kind = "annotation";
    inherit subject annotation;
  };
  envelope = scope: term: metadata: {
    inherit (representation) generation;
    inherit scope term metadata;
  };
  privateEnvelope =
    scope: root: metadata:
    representation.envelope scope root metadata;
  decode = value: decoder.decode value;
  admitted =
    scope: term: metadata:
    let
      value = decode (envelope scope term metadata);
    in
    if value.kind == "success" then
      privateEnvelope value.payload.scope value.payload.root value.payload.metadata
    else
      throw "fixture failed to decode";
  structurally =
    scope: left: right:
    operations.structurallyEqual (admitted scope left [ ]) (admitted scope right [ ]);
  metadataEntry = path: name: {
    inherit path name;
    location = [
      "fixture"
      (builtins.length path)
    ];
  };
  metadataPathsExist =
    value:
    let
      checked = operations.admitted value;
    in
    checked.ok && builtins.all (entry: builtins.elem entry.path checked.paths) checked.value.metadata;
  modulo = left: right: left - (builtins.div left right) * right;
  mapExpected =
    sourceScope: targetScope: freeMap: term:
    if term.kind == "variable" then
      variable (
        if term.level < sourceScope then freeMap term.level else term.level + targetScope - sourceScope
      )
    else if term.kind == "lambda" then
      lambda (mapExpected sourceScope targetScope freeMap term.body)
    else if term.kind == "application" then
      application (mapExpected sourceScope targetScope freeMap term.function) (
        mapExpected sourceScope targetScope freeMap term.argument
      )
    else
      annotation (mapExpected sourceScope targetScope freeMap term.subject) (
        mapExpected sourceScope targetScope freeMap term.annotation
      );

  generatedTerm =
    scope: seed:
    let
      first = modulo seed scope;
      second = modulo (seed + 1) scope;
    in
    annotation (application (variable first) (lambda (application (variable second) (variable scope)))) (
      application (variable second) (variable first)
    );
  generatedScopes = [
    1
    2
    3
    4
    5
    6
  ];
  generatedSeeds = [
    0
    1
    2
    3
    4
  ];
  generatedLawPass = builtins.all (
    scope:
    builtins.all (
      seed:
      let
        sourceTerm = generatedTerm scope seed;
        term = admitted scope sourceTerm [ ];
        embedding = builtins.genList (level: level * 2) scope;
        expectedWeakened = mapExpected scope (scope * 2) (level: level * 2) sourceTerm;
        expectedCollision = mapExpected scope 1 (_level: 0) sourceTerm;
        weakened = operations.weaken {
          envelope = term;
          targetScope = scope * 2;
          mapping = embedding;
        };
        collision = operations.rename {
          envelope = term;
          targetScope = 1;
          mapping = builtins.genList (_level: 0) scope;
        };
        invalid = operations.rename {
          envelope = term;
          targetScope = scope;
          mapping = builtins.genList (level: if level == 0 then scope else 0) scope;
        };
        identity = builtins.genList (level: admitted scope (variable level) [ ]) scope;
        substituted = operations.substitute {
          envelope = term;
          replacements = identity;
          targetScope = scope;
        };
      in
      weakened.ok
      && structurally (scope * 2) weakened.value.root expectedWeakened
      && collision.ok
      && structurally 1 collision.value.root expectedCollision
      && !invalid.ok
      && substituted.ok
      && operations.structurallyEqual term substituted.value
    ) generatedSeeds
  ) generatedScopes;

  transformSourceTerm = annotation (application (variable 0) (lambda (application (variable 1) (variable 2)))) (
    variable 1
  );
  transformSource = admitted 2 transformSourceTerm [ ];
  weakened = operations.weaken {
    envelope = transformSource;
    targetScope = 4;
    mapping = [
      1
      3
    ];
  };
  expectedWeakened = annotation (application (variable 1) (lambda (application (variable 3) (variable 4)))) (
    variable 3
  );
  collisionRenamed = operations.rename {
    envelope = transformSource;
    targetScope = 1;
    mapping = [
      0
      0
    ];
  };
  expectedCollision = annotation (application (variable 0) (lambda (application (variable 0) (variable 1)))) (
    variable 0
  );

  compositionSource = admitted 2 (annotation (application (variable 0) (variable 1)) (
    lambda (application (variable 0) (variable 2))
  )) [ ];
  firstReplacements = [
    (admitted 2 (application (variable 1) (variable 0)) [ ])
    (admitted 2 (lambda (application (variable 2) (variable 0))) [ ])
  ];
  secondReplacements = [
    (admitted 2 (lambda (application (variable 2) (variable 1))) [ ])
    (admitted 2 (application (variable 0) (variable 0)) [ ])
  ];
  firstApplied = operations.substitute {
    envelope = compositionSource;
    replacements = firstReplacements;
    targetScope = 2;
  };
  sequentialComposition = operations.substitute {
    envelope = firstApplied.value;
    replacements = secondReplacements;
    targetScope = 2;
  };
  composedReplacements = map (
    replacement:
    (operations.substitute {
      envelope = replacement;
      replacements = secondReplacements;
      targetScope = 2;
    }).value
  ) firstReplacements;
  directComposition = operations.substitute {
    envelope = compositionSource;
    replacements = composedReplacements;
    targetScope = 2;
  };

  replacementTerm = lambda (application (variable 1) (variable 0));
  replacementMetadata = [
    (metadataEntry [ ] "replacement-root")
    (metadataEntry [ "body" "function" ] "replacement-bound")
    (metadataEntry [ "body" "argument" ] "replacement-free")
  ];
  replacement = admitted 1 replacementTerm replacementMetadata;

  singleSubject = admitted 1 (variable 0) [
    (metadataEntry [ ] "stale-variable")
  ];
  singleSubstitution = operations.substitute {
    envelope = singleSubject;
    replacements = [ replacement ];
    targetScope = 1;
  };

  duplicatedSubject = admitted 1 (application (variable 0) (variable 0)) [
    (metadataEntry [ ] "application")
    (metadataEntry [ "function" ] "stale-left")
    (metadataEntry [ "argument" ] "stale-right")
  ];
  duplicatedSubstitution = operations.substitute {
    envelope = duplicatedSubject;
    replacements = [ replacement ];
    targetScope = 1;
  };
  expectedDuplicatedTerm = application replacementTerm replacementTerm;
  expectedDuplicatedMetadata = [
    (metadataEntry [ ] "application")
    ((metadataEntry [ ] "replacement-root") // { path = [ "function" ]; })
    (
      (metadataEntry [ "body" "function" ] "replacement-bound")
      // {
        path = [
          "function"
          "body"
          "function"
        ];
      }
    )
    (
      (metadataEntry [ "body" "argument" ] "replacement-free")
      // {
        path = [
          "function"
          "body"
          "argument"
        ];
      }
    )
    ((metadataEntry [ ] "replacement-root") // { path = [ "argument" ]; })
    (
      (metadataEntry [ "body" "function" ] "replacement-bound")
      // {
        path = [
          "argument"
          "body"
          "function"
        ];
      }
    )
    (
      (metadataEntry [ "body" "argument" ] "replacement-free")
      // {
        path = [
          "argument"
          "body"
          "argument"
        ];
      }
    )
  ];

  beneathBinderSubject = admitted 1 (lambda (application (variable 0) (variable 1))) [
    (metadataEntry [ "body" "function" ] "stale-free")
    (metadataEntry [ "body" "argument" ] "bound")
  ];
  beneathBinderSubstitution = operations.substitute {
    envelope = beneathBinderSubject;
    replacements = [ replacement ];
    targetScope = 1;
  };
  expectedBeneathBinder = lambda (application replacementTerm (variable 1));

  openingSourceTerm = lambda (application (variable 1) (variable 0));
  openingSource = admitted 1 openingSourceTerm [
    (metadataEntry [ ] "binder")
    (metadataEntry [ "body" ] "application")
    (metadataEntry [ "body" "function" ] "stale-binder-use")
    (metadataEntry [ "body" "argument" ] "free")
  ];
  openedWithMetadata = operations.open {
    envelope = openingSource;
    inherit replacement;
  };
  expectedOpenedTerm = application replacementTerm (variable 0);
  expectedOpenedMetadata = [
    ((metadataEntry [ "body" ] "application") // { path = [ ]; })
    ((metadataEntry [ ] "replacement-root") // { path = [ "function" ]; })
    (
      (metadataEntry [ "body" "function" ] "replacement-bound")
      // {
        path = [
          "function"
          "body"
          "function"
        ];
      }
    )
    (
      (metadataEntry [ "body" "argument" ] "replacement-free")
      // {
        path = [
          "function"
          "body"
          "argument"
        ];
      }
    )
    ((metadataEntry [ "body" "argument" ] "free") // { path = [ "argument" ]; })
  ];

  captureSource = admitted 1 (lambda (
    lambda (annotation (application (variable 0) (variable 1)) (variable 2))
  )) [ ];
  captured = operations.substitute {
    envelope = captureSource;
    replacements = [ (admitted 2 (variable 1) [ ]) ];
    targetScope = 2;
  };
  expectedCapture = lambda (lambda (annotation (application (variable 1) (variable 2)) (variable 3)));

  closeOpenSource = admitted 2 (lambda (
    annotation (application (variable 2) (variable 0)) (variable 0)
  )) [ ];
  closeOpenOpened = operations.open {
    envelope = closeOpenSource;
    replacement = admitted 2 (variable 1) [ ];
  };
  closeOpenClosed = operations.close {
    envelope = closeOpenOpened.value;
    sourceLevel = 1;
  };

  selectedSource = admitted 2 (application (variable 1) (variable 0)) [ ];
  selectedClosed = operations.close {
    envelope = selectedSource;
    sourceLevel = 1;
  };
  selectedOpened = operations.open {
    envelope = selectedClosed.value;
    replacement = admitted 2 (variable 1) [ ];
  };

  metadataTerm = annotation (application (variable 0) (lambda (variable 1))) (variable 0);
  unorderedMetadata = [
    (metadataEntry [ "annotation" ] "last")
    (metadataEntry [ ] "root")
    (metadataEntry [ "subject" "function" ] "middle")
  ];
  canonicalMetadata = decode (envelope 1 metadataTerm unorderedMetadata);

  exactMetadataPaths =
    (core.machine.validate {
      root = exactNodeTerm;
      scope = 0;
    }).paths;
  exactMetadata = map (path: metadataEntry path "node") exactMetadataPaths;
  exactMetadataResult = decode (envelope 0 exactNodeTerm exactMetadata);
  overMetadataResult = decode (envelope 0 exactNodeTerm (exactMetadata ++ [ poison ]));

  depthPath = builtins.genList (_index: "body") 64;
  depthMetadataTerm = nestedLambda 64 (variable 0);
  exactMetadataPathResult = decode (
    envelope 0 depthMetadataTerm [
      (metadataEntry depthPath "deep")
    ]
  );
  overMetadataPathResult = decode (
    envelope 0 depthMetadataTerm [
      {
        path = depthPath ++ [ poison ];
        name = "refused-path";
        location = [ ];
      }
    ]
  );

  exactLocationResult = decode (
    envelope 0 (lambda (variable 0)) [
      {
        path = [ ];
        name = "location";
        location = builtins.genList (index: index) 16;
      }
    ]
  );
  overLocationResult = decode (
    envelope 0 (lambda (variable 0)) [
      {
        path = [ ];
        name = "refused-location";
        location = builtins.genList (index: index) 16 ++ [ poison ];
      }
    ]
  );

  malformedMetadataComponent = decode (envelope 1 metadataTerm [ 1 ]);
  poisonedMetadataComponent = decode (envelope 1 metadataTerm [ poison ]);
  malformedPathComponent = decode (
    envelope 1 metadataTerm [
      {
        path = [ 1 ];
        name = "bad-path";
        location = [ ];
      }
    ]
  );
  poisonedPathComponent = decode (
    envelope 1 metadataTerm [
      {
        path = [ poison ];
        name = "poison-path";
        location = [ ];
      }
    ]
  );
  malformedLocationComponent = decode (
    envelope 1 metadataTerm [
      {
        path = [ ];
        name = "bad-location";
        location = [ true ];
      }
    ]
  );
  poisonedLocationComponent = decode (
    envelope 1 metadataTerm [
      {
        path = [ ];
        name = "poison-location";
        location = [ poison ];
      }
    ]
  );

  invalidMetadata = [
    (decode (envelope 1 metadataTerm [ (metadataEntry [ "missing" ] "bad") ]))
    (decode (envelope 1 metadataTerm [ (metadataEntry [ "subject" "body" ] "bad") ]))
    (decode (
      envelope 1 metadataTerm [
        (metadataEntry [ ] "first")
        (metadataEntry [ ] "second")
      ]
    ))
  ];
  internalInvalidMetadata = operations.admitted (
    privateEnvelope 1
      (representation.annotation (representation.application (representation.variable 0) (representation.lambda (representation.variable 1))) (
        representation.variable 0
      ))
      [ (metadataEntry [ "missing" ] "bad") ]
  );

  rootOuterCases = [
    (decode (envelope 0 1 [ ]))
    (decode (envelope 0 "text" [ ]))
    (decode (envelope 0 [ ] [ ]))
    (decode (envelope 0 (_value: null) [ ]))
  ];
  nestedOuterCases = [
    (decode (envelope 0 (lambda 1) [ ]))
    (decode (envelope 0 (lambda "text") [ ]))
    (decode (envelope 0 (lambda [ ]) [ ]))
    (decode (envelope 0 (lambda (_value: null)) [ ]))
  ];
  rootPoison = decode (envelope 0 poison [ ]);
  nestedPoisons = [
    (decode (envelope 0 (lambda poison) [ ]))
    (decode (envelope 1 (application (variable 0) poison) [ ]))
    (decode (envelope 1 (annotation poison (variable 0)) [ ]))
  ];

  malformedCases = [
    (decode {
      inherit (representation) generation;
      scope = 0;
      term = lambda (variable 0);
    })
    (decode ((envelope 0 (lambda (variable 0)) [ ]) // { extra = true; }))
    (decode (envelope 0 { kind = "future"; } [ ]))
    (decode (
      envelope 0 (
        {
          kind = "variable";
          level = 0;
        }
        // {
          checked = true;
        }
      ) [ ]
    ))
    (decode (envelope 0 (variable (-1)) [ ]))
    (decode (envelope 0 (variable 0) [ ]))
    (decode (envelope 1 (variable 1) [ ]))
    (decode ((envelope 0 poison [ ]) // { generation = "axiom-core-syntax-0"; }))
  ];

  repeated =
    depth: leaf:
    if depth == 0 then leaf else application (repeated (depth - 1) leaf) (repeated (depth - 1) leaf);
  stressSourceTerm = repeated 7 (variable 63);
  stressExpectedTerm = repeated 7 (variable 126);
  stressMapped = operations.weaken {
    envelope = admitted 64 stressSourceTerm [ ];
    targetScope = 128;
    mapping = builtins.genList (level: level * 2) 64;
  };

  balanced =
    depth: if depth == 0 then variable 0 else application (balanced (depth - 1)) (balanced (depth - 1));
  nestedLambda = count: tail: if count == 0 then tail else lambda (nestedLambda (count - 1) tail);
  exactNodeTerm = lambda (balanced 7);
  exactNodes = decode (envelope 0 exactNodeTerm [ ]);
  overNodes = decode (envelope 1 (application (balanced 7) poison) [ ]);
  exactDepth = decode (envelope 0 (nestedLambda 64 (variable 0)) [ ]);
  overDepth = decode (envelope 0 (nestedLambda 65 poison) [ ]);

  matrixTerms = [
    (representation.variable 0)
    (representation.lambda (representation.variable 3))
    (representation.application (representation.variable 0) (representation.variable 1))
    (representation.annotation (representation.variable 0) (representation.variable 1))
    (representation.universe (representation.levelSuc representation.levelZero))
    (representation.pi (representation.variable 0) (representation.variable 3))
    (representation.sigma (representation.variable 0) (representation.variable 3))
    (representation.sumType (representation.variable 0) (representation.variable 1))
    representation.unitType
    representation.unit
    representation.emptyType
    (representation.pair (representation.variable 0) (representation.variable 1))
    (representation.firstProjection (representation.variable 0))
    (representation.secondProjection (representation.variable 0))
    (representation.leftInjection (representation.variable 0))
    (representation.rightInjection (representation.variable 1))
    (representation.sumElimination (representation.variable 0) (representation.variable 3)
      (representation.variable 3)
      (representation.variable 3)
    )
    (representation.unitElimination (representation.variable 0) (representation.variable 3) (
      representation.variable 1
    ))
    (representation.emptyElimination (representation.variable 0) (representation.variable 3))
    (representation.identityType (representation.variable 0) (representation.variable 1) (
      representation.variable 2
    ))
    (representation.refl (representation.variable 0))
    (representation.identityElimination (representation.variable 0) (representation.variable 5) (
      representation.variable 3
    ))
  ];
  matrixEnvelope =
    term:
    let
      validated = core.machine.validate {
        root = term;
        scope = 3;
      };
      metadata = map (path: metadataEntry path "matrix") validated.paths;
    in
    representation.envelope 3 term metadata;
  matrixCheck =
    term:
    let
      source = operations.admitted (matrixEnvelope term);
      weakened = operations.weaken {
        envelope = source.value;
        targetScope = 6;
        mapping = [
          0
          2
          4
        ];
      };
      collision = operations.rename {
        envelope = source.value;
        targetScope = 1;
        mapping = [
          0
          0
          0
        ];
      };
      identity = operations.substitute {
        envelope = source.value;
        targetScope = 3;
        replacements = map (level: representation.envelope 3 (representation.variable level) [ ]) [
          0
          1
          2
        ];
      };
      firstReplacements = map (level: representation.envelope 3 (representation.variable level) [ ]) [
        1
        2
        0
      ];
      secondReplacements = map (level: representation.envelope 3 (representation.variable level) [ ]) [
        2
        0
        1
      ];
      firstApplied = operations.substitute {
        envelope = source.value;
        targetScope = 3;
        replacements = firstReplacements;
      };
      sequential = operations.substitute {
        envelope = firstApplied.value;
        targetScope = 3;
        replacements = secondReplacements;
      };
      composedReplacements = map (
        replacement:
        (operations.substitute {
          envelope = replacement;
          targetScope = 3;
          replacements = secondReplacements;
        }).value
      ) firstReplacements;
      directComposition = operations.substitute {
        envelope = source.value;
        targetScope = 3;
        replacements = composedReplacements;
      };
      capture = operations.substitute {
        envelope = source.value;
        targetScope = 3;
        replacements = [
          (representation.envelope 3 (representation.lambda (representation.variable 3)) [ ])
          (representation.envelope 3 (representation.pi (representation.variable 1) (
            representation.variable 3
          )) [ ])
          (representation.envelope 3 (representation.identityElimination (representation.variable 2)
            (representation.variable 5)
            (representation.variable 3)
          ) [ ])
        ];
      };
    in
    source.ok
    && weakened.ok
    && collision.ok
    && identity.ok
    && firstApplied.ok
    && sequential.ok
    && directComposition.ok
    && capture.ok
    && operations.structurallyEqual source.value identity.value
    && operations.structurallyEqual sequential.value directComposition.value
    && metadataPathsExist weakened.value
    && metadataPathsExist collision.value
    && metadataPathsExist identity.value
    && metadataPathsExist sequential.value
    && metadataPathsExist capture.value;
  matrixKinds = map (term: term.kind) matrixTerms;

  cases = {
    completeConstructorOperationMatrix =
      matrixKinds == representation.termKinds && builtins.all matrixCheck matrixTerms;
    generatedStructuralLaws = generatedLawPass;
    weakeningExact = weakened.ok && structurally 4 weakened.value.root expectedWeakened;
    collisionRenamingExact =
      collisionRenamed.ok && structurally 1 collisionRenamed.value.root expectedCollision;
    substitutionComposition =
      sequentialComposition.ok
      && directComposition.ok
      && operations.structurallyEqual sequentialComposition.value directComposition.value;
    singleReplacementMetadata =
      singleSubstitution.ok
      && structurally 1 singleSubstitution.value.root replacementTerm
      && singleSubstitution.value.metadata == replacementMetadata
      && metadataPathsExist singleSubstitution.value;
    duplicatedSubstitutionExact =
      duplicatedSubstitution.ok
      && structurally 1 duplicatedSubstitution.value.root expectedDuplicatedTerm
      && duplicatedSubstitution.value.metadata == expectedDuplicatedMetadata
      && metadataPathsExist duplicatedSubstitution.value;
    substitutionBeneathBinders =
      beneathBinderSubstitution.ok
      && structurally 1 beneathBinderSubstitution.value.root expectedBeneathBinder
      && !(builtins.any (entry: entry.name == "stale-free") beneathBinderSubstitution.value.metadata)
      && metadataPathsExist beneathBinderSubstitution.value;
    openingReplacementMetadata =
      openedWithMetadata.ok
      && structurally 1 openedWithMetadata.value.root expectedOpenedTerm
      && openedWithMetadata.value.metadata == expectedOpenedMetadata
      && metadataPathsExist openedWithMetadata.value;
    nestedCaptureExact = captured.ok && structurally 2 captured.value.root expectedCapture;
    openThenClose =
      closeOpenOpened.ok
      && closeOpenClosed.ok
      && operations.structurallyEqual closeOpenSource closeOpenClosed.value;
    closeThenOpen =
      selectedClosed.ok
      && selectedOpened.ok
      && operations.structurallyEqual selectedSource selectedOpened.value;
    metadataCanonicalOrder =
      canonicalMetadata.kind == "success"
      &&
        map (entry: entry.name) canonicalMetadata.payload.metadata == [
          "root"
          "middle"
          "last"
        ];
    metadataMalformedRejected = builtins.all (value: value.kind == "boundary-mismatch") invalidMetadata;
    metadataExactLimit =
      exactMetadataResult.kind == "success"
      && builtins.length exactMetadataResult.payload.metadata == 256;
    metadataRefusedPoison =
      overMetadataResult.kind == "resource-exhaustion"
      && overMetadataResult.budget == "core-syntax-metadata"
      && overMetadataResult.dimension == "nodes"
      && overMetadataResult.limit == 256
      && overMetadataResult.consumed == 256;
    metadataPathExactLimit = exactMetadataPathResult.kind == "success";
    metadataPathRefusedPoison =
      overMetadataPathResult.kind == "resource-exhaustion"
      && overMetadataPathResult.budget == "core-syntax-metadata-path"
      && overMetadataPathResult.dimension == "depth"
      && overMetadataPathResult.limit == 64
      && overMetadataPathResult.consumed == 64;
    metadataLocationExactLimit = exactLocationResult.kind == "success";
    metadataLocationRefusedPoison =
      overLocationResult.kind == "resource-exhaustion"
      && overLocationResult.budget == "core-syntax-metadata-location"
      && overLocationResult.dimension == "nodes"
      && overLocationResult.limit == 16
      && overLocationResult.consumed == 16;
    malformedMetadataComponentRejected = malformedMetadataComponent.kind == "boundary-mismatch";
    poisonedMetadataComponentRejected = poisonedMetadataComponent.kind == "host-failure";
    malformedPathComponentRejected = malformedPathComponent.kind == "boundary-mismatch";
    poisonedPathComponentRejected = poisonedPathComponent.kind == "host-failure";
    malformedLocationComponentRejected = malformedLocationComponent.kind == "boundary-mismatch";
    poisonedLocationComponentRejected = poisonedLocationComponent.kind == "host-failure";
    internalMetadataRejected = !internalInvalidMetadata.ok;
    nonAttrRootsMismatch = builtins.all (value: value.kind == "boundary-mismatch") rootOuterCases;
    nonAttrChildrenMismatch = builtins.all (value: value.kind == "boundary-mismatch") nestedOuterCases;
    poisonRootHostFailure = rootPoison.kind == "host-failure";
    poisonChildrenHostFailure = builtins.all (value: value.kind == "host-failure") nestedPoisons;
    malformedRejected = builtins.all (value: value.kind != "success") malformedCases;
    preparedMapStress = stressMapped.ok && structurally 128 stressMapped.value.root stressExpectedTerm;
    exactNodeBoundary = exactNodes.kind == "success" && exactNodes.payload.nodes == 256;
    nodePoisonRefused =
      overNodes.kind == "resource-exhaustion"
      && overNodes.dimension == "nodes"
      && overNodes.consumed == 256;
    exactDepthBoundary = exactDepth.kind == "success";
    depthPoisonRefused =
      overDepth.kind == "resource-exhaustion" && overDepth.dimension == "depth" && overDepth.limit == 64;
    syntaxGenerationFrozen = representation.generation == "axiom-core-syntax-2";
    resourceLimitsFrozen =
      representation.limits == {
        nodes = 256;
        depth = 64;
        locationComponents = 16;
      };
    inventoryFrozen =
      representation.termKinds == [
        "variable"
        "lambda"
        "application"
        "annotation"
        "universe"
        "pi"
        "sigma"
        "sum-type"
        "unit-type"
        "unit"
        "empty-type"
        "pair"
        "first-projection"
        "second-projection"
        "left-injection"
        "right-injection"
        "sum-elimination"
        "unit-elimination"
        "empty-elimination"
        "identity-type"
        "refl"
        "identity-elimination"
      ]
      &&
        representation.levelKinds == [
          "zero"
          "suc"
          "max"
        ];
  };
  failing = builtins.attrNames (
    builtins.removeAttrs cases (builtins.filter (name: cases.${name}) (builtins.attrNames cases))
  );
  ok =
    if builtins.all (name: cases.${name}) (builtins.attrNames cases) then
      true
    else
      throw "axiom core syntax tests FAILED: ${builtins.concatStringsSep ", " failing}";
in
{
  inherit cases ok;
}
