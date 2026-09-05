import json
import pathlib
import statistics
import subprocess
import time

root = pathlib.Path(__file__).resolve().parents[1]
common = '''
let
  root = ROOT;
  pin = (builtins.fromJSON (builtins.readFile (root + "/flake.lock"))).nodes.nixpkgs.locked;
  lib = import ((builtins.fetchTree pin).outPath + "/lib");
  axiom = import (root + "/src") { inherit lib; };
  names = n: builtins.genList (i: "name-${toString i}") n;
in
'''.replace("ROOT", str(root))
workloads = {
    "requirements": '''
let
  required = names 2048;
  result = axiom.requirements.observe {
    inherit required;
    candidates = builtins.genList (i: { provides = required ++ [ "extra-${toString i}" ]; }) 24;
    providedBy = c: c.provides;
  };
in builtins.length result.qualified
''',
    "phases": '''
let
  phases = names 256;
  result = axiom.phases.compile {
    names = phases;
    registrations = builtins.genList (i: { phase = builtins.elemAt phases (i - (builtins.div i 256) * 256); }) 8192;
    phaseOf = r: r.phase;
    runnable = _: true;
    onUnknown = _: _: "unknown";
    onInvalid = _: _: "invalid";
  };
in builtins.foldl' (n: xs: n + builtins.length xs) 0 (builtins.attrValues result.value.byName)
''',
    "schema": '''
let
  keys = names 2048;
  parse = axiom.schema.compile {
    fields = lib.genAttrs keys (_: {});
    onRecord = _: "record";
    onUnknown = name: _: name;
  };
  result = parse (lib.genAttrs keys (_: 1));
in builtins.length (builtins.attrNames result.value)
''',
}
expected = {"requirements": 24, "phases": 8192, "schema": 2048}
report = {"nix": subprocess.check_output(["nix", "--version"], text=True).strip(), "samples": {}}
for name, expression in workloads.items():
    samples = []
    for attempt in range(4):
        started = time.perf_counter()
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "--expr", common + expression],
            text=True, capture_output=True, check=True, timeout=180,
        )
        elapsed = time.perf_counter() - started
        value = json.loads(result.stdout)
        if value != expected[name]:
            raise RuntimeError(f"{name}: expected {expected[name]}, got {value}")
        if attempt:
            samples.append(elapsed)
    report["samples"][name] = {"seconds": samples, "median": statistics.median(samples), "result": value}
print(json.dumps(report, indent=2))
