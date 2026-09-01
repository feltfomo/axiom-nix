# raw host measurements taken before the conversion relation rewrite, kept apart
# from the semantic expectations in operations.nix so that a later rewrite can
# change these numbers without touching any admitted cost
let
  fixtures = import ./operations.nix;
  observer = import ../../language/internal/operation-observer.nix;
  sorted = builtins.sort (left: right: left < right);
  sumOf = builtins.foldl' (running: value: running + value) 0;
  legNames = sorted fixtures.legNames;
in
rec {
  # the rungs are irregular so neighbouring pairs cannot be read as doubling
  inherit (fixtures) ladder;
  environment = {
    evaluator = "lix 2.96.0-dev-pre20260728-dev_64c99ac";
    system = "x86_64-linux";
    host = "linux 7.2.0-cachyos";
    cores = 16;
    command = "axiom-measure over the staged source path";
    recorded = "2026-09-01";
  };
  # executed operation events per rung and per workload leg, exactly as counted
  # from the trace stream
  counts = {
    "3" = {
      unitContext = 255;
      unitInference = 690;
      towerContext = 174;
      towerVariable = 201;
      towerProjection = 370;
      readback = 390;
      conversion = 663;
      oracle = 415;
    };
    "5" = {
      unitContext = 441;
      unitInference = 1278;
      towerContext = 344;
      towerVariable = 371;
      towerProjection = 814;
      readback = 764;
      conversion = 1315;
      oracle = 859;
    };
    "11" = {
      unitContext = 1191;
      unitInference = 3858;
      towerContext = 1046;
      towerVariable = 1073;
      towerProjection = 2818;
      readback = 2270;
      conversion = 4039;
      oracle = 2863;
    };
    "23" = {
      unitContext = 3555;
      unitInference = 12690;
      towerContext = 3314;
      towerVariable = 3341;
      towerProjection = 9850;
      readback = 7010;
      conversion = 12943;
      oracle = 9895;
    };
    "37" = {
      unitContext = 7769;
      unitInference = 29182;
      towerContext = 7416;
      towerVariable = 7443;
      towerProjection = 23150;
      readback = 15452;
      conversion = 29155;
      oracle = 23195;
    };
  };
  # totals over the whole ladder, one entry per operation that actually executed
  totals = {
    "core.admission.attempt" = 2731;
    "core.admission.node" = 37829;
    "evaluation.direct.semantic-node" = 5666;
    "logismos.computation.instruction" = 73991;
    "logismos.transition.step" = 113487;
    "kernel.conversion.type" = 153;
    "kernel.conversion.oracle" = 5;
    all = 233862;
  };
  # these admitted operations never executed under this ladder, which records a
  # gap in the workload rather than evidence about the operations themselves
  absent = [
    "evaluation.machine.transition"
    "kernel.transition.typed-neutral"
    "kernel.conversion.term"
    "kernel.conversion.neutral"
  ];
  # derived reading of the numbers above, deliberately modest because five rungs
  # cannot settle an asymptotic class
  interpretation = {
    method = "compare each rung against the count per unit of depth at the first rung";
    perLeg = {
      unitContext = "visibly above the linear projection";
      unitInference = "visibly above the linear projection";
      towerContext = "visibly above the linear projection";
      towerVariable = "visibly above the linear projection";
      towerProjection = "visibly above the linear projection";
      readback = "visibly above the linear projection";
      conversion = "visibly above the linear projection";
      oracle = "visibly above the linear projection";
    };
    # the oracle decision itself carries a constant semantic vector, so its host
    # counts grow with the constructed workload and not with the decision
    caveats = [
      "growth is reported over this ladder only and is not a proven class"
      "oracle counts follow workload construction rather than the oracle decision"
      "absent operations are unexercised here and no independence follows from that"
    ];
  };
  # the record checks its own arithmetic and its own closure against the observer
  # inventory, so a hand edited number or a dropped leg cannot pass unnoticed
  evidence =
    let
      rungs = builtins.attrValues counts;
      rungSum = sumOf (map (legs: sumOf (builtins.attrValues legs)) rungs);
      present = builtins.filter (name: name != "all") (builtins.attrNames totals);
      operationSum = sumOf (map (name: totals.${name}) present);
    in
    {
      baselineCoversLadder =
        builtins.length (builtins.attrNames counts) == builtins.length ladder
        && builtins.all (rung: builtins.hasAttr (builtins.toString rung) counts) ladder;
      baselineRecordsEveryLeg = builtins.all (legs: builtins.attrNames legs == legNames) rungs;
      baselineRungsHaveEightLegs = builtins.all (
        legs: builtins.length (builtins.attrNames legs) == 8
      ) rungs;
      baselineRungCountsSumToTotal = rungSum == totals.all;
      baselineOperationTotalsSumToTotal = operationSum == totals.all;
      baselineOperationInventoryClosed =
        sorted (present ++ absent) == sorted observer.operations
        && builtins.all (name: !builtins.elem name absent) present;
    };
}
