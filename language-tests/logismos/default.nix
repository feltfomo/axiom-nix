{ lib }:
let
  logismos = import ../../language/logismos;
  inherit (logismos)
    computation
    relation
    transition
    traversal
    ;
  poison = import ./poison.nix;
  initialState = {
    count = 0;
    order = [ ];
  };
  reader = {
    name = "reader-value";
  };
  observe = computation.materialize {
    success = payload: finalState: {
      branch = "success";
      inherit payload finalState;
    };
    failure = opaqueFailure: finalState: {
      branch = "failure";
      inherit opaqueFailure finalState;
    };
  };
  execute =
    program:
    observe (
      computation.run {
        computation = program;
        inherit reader;
        state = initialState;
      }
    );
  emit =
    name:
    computation.modify (
      state:
      state
      // {
        count = state.count + 1;
        order = state.order ++ [ name ];
      }
    );
  integerEquality =
    left: right:
    if builtins.isInt left && builtins.isInt right && left == right then
      computation.pure null
    else
      computation.fail poison.opaqueFailure;

  leftIdentityLeft = execute (
    computation.bind (computation.pure 4) (value: computation.pure (value + 1))
  );
  leftIdentityRight = execute (computation.pure 5);
  rightIdentityLeft = execute (computation.bind (computation.pure 4) computation.pure);
  rightIdentityRight = execute (computation.pure 4);
  associativityLeft = execute (
    computation.bind (computation.bind (computation.pure 2) (value: computation.pure (value + 3))) (
      value: computation.pure (value * 4)
    )
  );
  associativityRight = execute (
    computation.bind (computation.pure 2) (
      value: computation.bind (computation.pure (value + 3)) (next: computation.pure (next * 4))
    )
  );
  failureLeftZero = execute (
    computation.bind (computation.fail poison.opaqueFailure) (_value: poison.poison)
  );
  mapIdentity = execute (computation.map (value: value) (computation.pure 9));
  mapCompositionLeft = execute (computation.map (value: (value + 2) * 3) (computation.pure 4));
  mapCompositionRight = execute (
    computation.map (value: value * 3) (computation.map (value: value + 2) (computation.pure 4))
  );
  ordered = execute (
    computation.traverse emit [
      "a"
      "b"
      "c"
    ]
  );
  pureTraversal = execute (
    computation.traverse computation.pure [
      1
      2
      3
    ]
  );
  productOrdered = execute (
    computation.product (computation.bind (emit "product-left") (_unit: computation.pure 1)) (
      computation.bind (emit "product-right") (_unit: computation.pure 2)
    )
  );
  productFailure = execute (
    computation.product (computation.fail poison.opaqueFailure) poison.poison
  );
  dynamicReaderState = execute (
    computation.bind (emit "before") (
      _unit:
      computation.bind computation.ask (
        suppliedReader:
        computation.bind computation.get (
          latestState:
          computation.pure {
            readerName = suppliedReader.name;
            countSeen = latestState.count;
            orderSeen = latestState.order;
          }
        )
      )
    )
  );
  failureState = execute (
    computation.bind (emit "charged") (
      _unit: computation.bind (computation.fail poison.opaqueFailure) (_value: poison.poison)
    )
  );
  runtimeFailure = execute (
    computation.bind (computation.pure null) (
      _unit:
      computation.bind (computation.bind (computation.fail poison.opaqueFailure) (
        _value: poison.poison
      )) (_value: poison.poison)
    )
  );
  deepProgram = builtins.foldl' (
    program: _index: computation.bind program (value: computation.pure (value + 1))
  ) (computation.pure 0) (builtins.genList (index: index) 10000);
  deep = execute deepProgram;

  boundaryResult = import ../../language/boundary/result.nix;
  evaluationResult = import ../../language/evaluation/result.nix;
  core = import ../../language/core;
  evaluation = import ../../language/evaluation { inherit core; };
  kernelRepresentation = import ../../language/kernel/representation.nix { inherit evaluation; };
  kernelResult = import ../../language/kernel/result.nix {
    representation = kernelRepresentation;
    inherit core;
  };
  materializationState = {
    nodes = 3;
    trace = [
      "newest"
      "oldest"
    ];
  };
  successProgram = computation.run {
    computation = computation.pure "evidence";
    reader = null;
    state = materializationState;
  };
  boundaryFailureValue = boundaryResult.hostFailure {
    operation = "logismos";
    path = [ "failure" ];
    guardedOperation = "fixture";
  };
  evaluationFailureValue =
    evaluationResult.internalBug evaluationResult.codes.impossibleMachineState
      {
        owner = "logismos";
      };
  kernelFailureValue = kernelResult.internal "logismos" 2 kernelResult.codes.impossibleState;
  boundarySuccess = computation.materialize {
    success =
      payload: _state:
      boundaryResult.success {
        operation = "logismos";
        path = [ "success" ];
        policy = "opaque";
        category = null;
        inherit payload;
      };
    failure = failure: _state: failure;
  } successProgram;
  boundaryFailure =
    computation.materialize
      {
        success = _payload: _state: poison.poison;
        failure = failure: _state: failure;
      }
      (
        computation.run {
          computation = computation.fail boundaryFailureValue;
          reader = null;
          state = materializationState;
        }
      );
  evaluationSuccess = computation.materialize {
    inherit (evaluationResult) success;
    failure = failure: _state: failure;
  } successProgram;
  evaluationFailure =
    computation.materialize
      {
        success = _payload: _state: poison.poison;
        failure = failure: _state: failure;
      }
      (
        computation.run {
          computation = computation.fail evaluationFailureValue;
          reader = null;
          state = materializationState;
        }
      );
  kernelSuccess = computation.materialize {
    success =
      value: resources:
      kernelResult.checking {
        type = "opaque-type";
        inherit value resources;
      };
    failure = failure: _state: failure;
  } successProgram;
  kernelFailure =
    computation.materialize
      {
        success = _payload: _state: poison.poison;
        failure = failure: _state: failure;
      }
      (
        computation.run {
          computation = computation.fail kernelFailureValue;
          reader = null;
          state = materializationState;
        }
      );

  replayed = transition.replay {
    initial = [ ];
    spine = [
      "newest"
      "middle"
      "oldest"
    ];
    step = values: value: values ++ [ value ];
  };
  firstTerminal = transition.iterate {
    initial = {
      count = 0;
    };
    terminal = state: state.count >= 5;
    step = state: { count = state.count + 1; };
  };
  deepTransition = transition.iterate {
    initial = {
      count = 0;
    };
    terminal = state: state.count == 10000;
    step = state: { count = state.count + 1; };
  };
  composed = transition.compose [
    (value: value + 2)
    (value: value * 3)
  ] 4;

  tree = {
    kind = "pair";
    children = [
      {
        kind = "leaf";
        children = [ ];
        value = 2;
        label = "left";
      }
      {
        kind = "leaf";
        children = [ ];
        value = 5;
        label = "right";
      }
    ];
  };
  treeFold = execute (
    traversal.fold {
      kinds = [
        "leaf"
        "pair"
      ];
      handlers = {
        leaf = node: _children: {
          total = node.value;
          order = [ node.label ];
        };
        pair = _node: children: {
          total = (builtins.elemAt children 0).total + (builtins.elemAt children 1).total;
          order = (builtins.elemAt children 0).order ++ (builtins.elemAt children 1).order;
        };
      };
      root = tree;
      limit = 3;
      refusal = poison.opaqueFailure;
    }
  );
  treeExact = execute (
    traversal.bounded {
      kinds = [
        "leaf"
        "pair"
      ];
      handlers = {
        leaf = node: _children: node.value;
        pair = _node: children: builtins.elemAt children 0 + builtins.elemAt children 1;
      };
      root = tree;
      limit = 3;
      refusal = poison.opaqueFailure;
    }
  );
  treeOver = execute (
    traversal.bounded {
      kinds = [
        "leaf"
        "pair"
      ];
      handlers = {
        leaf = node: _children: node.value;
        pair = _node: children: builtins.elemAt children 0 + builtins.elemAt children 1;
      };
      root = tree;
      limit = 2;
      refusal = poison.opaqueFailure;
    }
  );
  refusalBeforeInspection = execute (
    traversal.bounded {
      kinds = [ "leaf" ];
      handlers = {
        leaf = node: _children: node.value;
      };
      root = poison.poison;
      limit = 0;
      refusal = poison.opaqueFailure;
    }
  );
  rewritten = execute (
    traversal.rewrite {
      kinds = [
        "leaf"
        "pair"
      ];
      root = tree;
      limit = 3;
      refusal = poison.opaqueFailure;
      rewriteNode = node: if node.kind == "leaf" then node // { value = node.value + 1; } else node;
    }
  );
  zipped = execute (
    traversal.zipFold {
      left = [
        1
        2
        3
      ];
      right = [
        1
        2
        3
      ];
      mismatch = poison.opaqueFailure;
      combine = integerEquality;
    }
  );
  zipMismatch = execute (
    traversal.zipFold {
      left = [ 1 ];
      right = [
        1
        2
      ];
      mismatch = poison.opaqueFailure;
      combine = _left: _right: poison.poison;
    }
  );

  productRelation = execute (relation.product integerEquality integerEquality [ 1 2 ] [ 1 2 ]);
  sumRelation = relation.sum {
    classify = value: value.kind;
    leftRelation = integerEquality;
    rightRelation = _left: _right: poison.poison;
    mismatch = poison.opaqueFailure;
  };
  selectedSum = execute (
    sumRelation
      {
        kind = "left";
        value = 4;
      }
      {
        kind = "left";
        value = 4;
      }
  );
  mismatchedSum = execute (
    sumRelation
      {
        kind = "left";
        value = 4;
      }
      {
        kind = "right";
        value = poison.poison;
      }
  );
  dependentRelation = execute (
    relation.dependentProduct integerEquality
      (
        leftFirst: rightFirst: leftSecond: rightSecond:
        if leftFirst == rightFirst then integerEquality leftSecond rightSecond else poison.poison
      )
      {
        first = 2;
        second = 6;
      }
      {
        first = 2;
        second = 6;
      }
  );
  extensionalRelation = execute (
    relation.extensional {
      fresh = 3;
      apply = function: function;
      relation = integerEquality;
    } (value: value + 1) (value: value + 1)
  );
  pointwiseRelation = execute (
    relation.pointwise integerEquality poison.opaqueFailure [ 1 2 3 ] [ 1 2 3 ]
  );

  budget = logismos.budget.make {
    dimensions = [
      "depth"
      "nodes"
    ];
    namedCosts = {
      inspect = {
        depth = 0;
        nodes = 1;
      };
      descend = {
        depth = 1;
        nodes = 1;
      };
    };
  };
  vectorA = {
    depth = 1;
    nodes = 2;
  };
  vectorB = {
    depth = 2;
    nodes = 3;
  };
  vectorLimit = {
    depth = 3;
    nodes = 5;
  };
  budgetExact = execute (
    budget.charge {
      limit = vectorLimit;
      usage = vectorA;
      cost = vectorB;
      refusal = poison.opaqueFailure;
    }
  );
  budgetOver = execute (
    computation.bind (budget.charge {
      limit = vectorLimit;
      usage = vectorA;
      cost = {
        depth = 3;
        nodes = 4;
      };
      refusal = poison.opaqueFailure;
    }) (_usage: poison.poison)
  );

  contains = needle: text: builtins.replaceStrings [ needle ] [ "" ] text != text;
  computationSource = builtins.readFile ../../language/logismos/computation.nix;
  relationSource = builtins.readFile ../../language/logismos/relation.nix;
  traversalSource = builtins.readFile ../../language/logismos/traversal.nix;
  testSource = builtins.readFile ./default.nix;
  logismosExports = builtins.attrNames logismos;
  computationExports = builtins.attrNames computation;
  relationExports = builtins.attrNames relation;
  transitionExports = builtins.attrNames transition;
  traversalExports = builtins.attrNames traversal;
  budgetExports = builtins.attrNames logismos.budget;
  privateOkSelector = builtins.concatStringsSep "" [
    ".o"
    "k"
  ];
  privateStateSelector = builtins.concatStringsSep "" [
    ".sta"
    "te"
  ];

  cases = {
    computationLeftIdentity = leftIdentityLeft == leftIdentityRight;
    computationRightIdentity = rightIdentityLeft == rightIdentityRight;
    computationAssociativity = associativityLeft == associativityRight;
    failureLeftZero = failureLeftZero.branch == "failure";
    mapIdentity = mapIdentity.payload == 9;
    mapComposition = mapCompositionLeft == mapCompositionRight;
    failedContinuationLazy = failureLeftZero.opaqueFailure == poison.opaqueFailure;
    runtimeFailureLazy = runtimeFailure.branch == "failure";
    stateAtFailure =
      failureState.finalState == {
        count = 1;
        order = [ "charged" ];
      };
    writtenOrder =
      ordered.finalState == {
        count = 3;
        order = [
          "a"
          "b"
          "c"
        ];
      };
    pureTraverseLaw =
      pureTraversal.payload == [
        1
        2
        3
      ]
      && pureTraversal.finalState == initialState;
    computationProduct =
      productOrdered.payload == [
        1
        2
      ];
    computationProductOrder =
      productOrdered.finalState == {
        count = 2;
        order = [
          "product-left"
          "product-right"
        ];
      };
    computationProductFailureLazy =
      productFailure.branch == "failure" && productFailure.opaqueFailure == poison.opaqueFailure;
    dynamicReaderLatestState =
      dynamicReaderState.payload == {
        readerName = "reader-value";
        countSeen = 1;
        orderSeen = [ "before" ];
      };
    deepPipeline = deep.payload == 10000;
    boundarySuccessShape =
      builtins.attrNames boundarySuccess == [
        "category"
        "kind"
        "operation"
        "path"
        "payload"
        "policy"
      ];
    boundaryFailureShape = boundaryFailure == boundaryFailureValue;
    evaluationSuccessShape =
      builtins.attrNames evaluationSuccess == [
        "kind"
        "nodes"
        "ok"
        "trace"
        "value"
      ];
    evaluationFailureShape = evaluationFailure == evaluationFailureValue;
    kernelSuccessShape =
      builtins.attrNames kernelSuccess == [
        "generation"
        "kind"
        "ok"
        "resources"
        "type"
        "value"
      ];
    kernelFailureShape = kernelFailure == kernelFailureValue;
    transitionComposition = composed == 18;
    oldestFirstReplay =
      replayed.value == [
        "oldest"
        "middle"
        "newest"
      ];
    firstTerminalObservation = firstTerminal.count == 5;
    deepTransition = deepTransition.count == 10000;
    closedFoldOrder =
      treeFold.payload.value == {
        total = 7;
        order = [
          "left"
          "right"
        ];
      };
    exactBound = treeExact.branch == "success" && treeExact.payload.consumed == 3;
    overBound = treeOver.branch == "failure";
    noInspectionAfterRefusal = refusalBeforeInspection.branch == "failure";
    rewrite = (builtins.elemAt rewritten.payload.value.children 0).value == 3;
    zipFold = zipped.branch == "success" && builtins.length zipped.payload == 3;
    zipMismatch = zipMismatch.branch == "failure";
    productRelation = productRelation.branch == "success";
    selectedSumLazy = selectedSum.branch == "success";
    sumMismatchOpaque = mismatchedSum.opaqueFailure == poison.opaqueFailure;
    dependentProduct = dependentRelation.branch == "success";
    extensional = extensionalRelation.branch == "success";
    pointwise = pointwiseRelation.branch == "success";
    budgetZero =
      budget.zero == {
        depth = 0;
        nodes = 0;
      };
    budgetAdd = budget.add vectorA vectorB == vectorLimit;
    budgetOrder = budget.lessOrEqual vectorA vectorLimit;
    budgetRemaining = budget.remaining vectorLimit vectorA == vectorB;
    budgetValid =
      budget.valid vectorA
      && !(budget.valid {
        depth = -1;
        nodes = 0;
      });
    budgetMonotone = budget.lessOrEqual vectorA (budget.add vectorA vectorB);
    budgetExact = budgetExact.payload == vectorLimit;
    budgetRefusalLazy = budgetOver.branch == "failure";
    budgetNoNegative = builtins.all (value: value >= 0) (
      builtins.attrValues (budget.remaining vectorLimit vectorA)
    );
    budgetMaximumDepth =
      budget.maximumDepth vectorA 4 == {
        depth = 4;
        nodes = 2;
      };
    namedCosts =
      budget.namedCosts.inspect == {
        depth = 0;
        nodes = 1;
      };
    logismosExportSet =
      logismosExports == [
        "budget"
        "computation"
        "relation"
        "transition"
        "traversal"
      ];
    computationExportSet =
      computationExports == [
        "ask"
        "bind"
        "fail"
        "get"
        "map"
        "materialize"
        "modify"
        "product"
        "pure"
        "run"
        "traverse"
      ];
    relationExportSet =
      relationExports == [
        "dependentProduct"
        "extensional"
        "pointwise"
        "product"
        "sum"
      ];
    transitionExportSet =
      transitionExports == [
        "compose"
        "iterate"
        "replay"
        "run"
      ];
    traversalExportSet =
      traversalExports == [
        "bounded"
        "fold"
        "rewrite"
        "zipFold"
      ];
    budgetExportSet = budgetExports == [ "make" ];
    closedInstructions =
      contains ''kind = "bind"'' computationSource
      && contains ''else if instruction.kind == "bind"'' computationSource
      && contains ''throw "logismos internal instruction kind"'' computationSource
      && !(contains "handlers" computationSource);
    constantTimeBindShape =
      contains "instructions = [" computationSource
      && contains "++ computation.instructions;" computationSource
      && !(contains "computation.instructions ++" computationSource);
    relationUsesCarrier =
      contains "bind (leftRelation" relationSource && contains "traverse" relationSource;
    traversalUsesCarrier =
      contains "computation.traverse" traversalSource && contains "computation.fail" traversalSource;
    clientsAvoidPrivateResults =
      !(contains privateOkSelector testSource) && !(contains privateStateSelector testSource);
  };
  failed = builtins.filter (name: !cases.${name}) (builtins.attrNames cases);
  ok =
    if failed == [ ] then
      true
    else
      throw "axiom logismos tests FAILED: ${lib.concatStringsSep ", " failed}";
in
{
  inherit cases ok;
}
