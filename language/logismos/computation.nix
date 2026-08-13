{ stack }:
let
  reverse = builtins.foldl' (values: value: [ value ] ++ values) [ ];
  last = values: builtins.elemAt values (builtins.length values - 1);
  successSeed = value: {
    kind = "success";
    inherit value;
  };
  failureSeed = failure: {
    kind = "failure";
    inherit failure;
  };
  program = seed: instructions: { inherit seed instructions; };

  pureComputation = value: program (successSeed value) [ ];
  failComputation = failure: program (failureSeed failure) [ ];

  # newest-first storage keeps bind to one cons
  bindComputation =
    computation: continuation:
    computation
    // {
      instructions = [
        {
          kind = "bind";
          inherit continuation;
        }
      ]
      ++ computation.instructions;
    };

  mapComputation =
    transform: computation: bindComputation computation (value: pureComputation (transform value));

  productComputation =
    left: right:
    bindComputation left (
      leftValue:
      mapComputation (rightValue: [
        leftValue
        rightValue
      ]) right
    );

  traverseComputation =
    transform: values:
    mapComputation reverse (
      builtins.foldl' (
        computation: value:
        bindComputation computation (
          results: mapComputation (result: [ result ] ++ results) (transform value)
        )
      ) (pureComputation [ ]) values
    );

  askComputation = program (successSeed null) [ { kind = "reader"; } ];
  getComputation = program (successSeed null) [ { kind = "state"; } ];
  modifyComputation =
    transition:
    program (successSeed null) [
      {
        kind = "modify";
        inherit transition;
      }
    ];

  runComputation =
    {
      computation,
      reader,
      state,
    }:
    let
      initial = {
        key = 0;
        status = if computation.seed.kind == "success" then "running" else "failure";
        current = if computation.seed.kind == "success" then computation.seed.value else null;
        failure = if computation.seed.kind == "failure" then computation.seed.failure else null;
        # bind stores backwards, so this is the one conversion into written runtime order
        worklist =
          if computation.seed.kind == "success" then
            stack.fromNewestFirst computation.instructions
          else
            stack.empty;
        inherit reader state;
      };
      # deep pipelines stay off the nix call stack at the cost of one retained state per step
      final = last (
        builtins.genericClosure {
          startSet = [ initial ];
          operator =
            current:
            if current.status != "running" then
              [ ]
            else if stack.isEmpty current.worklist then
              [
                (
                  current
                  // {
                    key = current.key + 1;
                    status = "success";
                  }
                )
              ]
            else
              let
                instruction = stack.top current.worklist;
                remaining = stack.pop current.worklist;
                advanced =
                  if instruction.kind == "reader" then
                    current
                    // {
                      current = current.reader;
                      worklist = remaining;
                    }
                  else if instruction.kind == "state" then
                    current
                    // {
                      current = current.state;
                      worklist = remaining;
                    }
                  else if instruction.kind == "modify" then
                    current
                    // {
                      current = null;
                      state = instruction.transition current.state;
                      worklist = remaining;
                    }
                  else if instruction.kind == "bind" then
                    let
                      produced = instruction.continuation current.current;
                    in
                    if produced.seed.kind == "failure" then
                      # the refusing state survives, but its tail must become unreachable
                      current
                      // {
                        status = "failure";
                        failure = produced.seed.failure;
                        worklist = stack.empty;
                      }
                    else
                      # a returned program runs in written order before the older persistent tail
                      current
                      // {
                        current = produced.seed.value;
                        worklist = stack.prependNewestFirst produced.instructions remaining;
                      }
                  else
                    throw "logismos internal instruction kind";
              in
              [ (advanced // { key = current.key + 1; }) ];
        }
      );
    in
    if final.status == "success" then
      {
        kind = "success";
        value = final.current;
        inherit (final) state;
      }
    else
      {
        kind = "failure";
        inherit (final) failure state;
      };

  materializeComputation =
    adapters: result:
    if result.kind == "success" then
      adapters.success result.value result.state
    else
      adapters.failure result.failure result.state;
in
{
  pure = pureComputation;
  fail = failComputation;
  bind = bindComputation;
  map = mapComputation;
  product = productComputation;
  traverse = traverseComputation;
  ask = askComputation;
  get = getComputation;
  modify = modifyComputation;
  run = runComputation;
  materialize = materializeComputation;
}
