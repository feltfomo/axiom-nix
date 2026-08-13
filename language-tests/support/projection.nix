{ representation, result }:
let
  logismos = import ../../language/logismos;
  inherit (logismos) computation transition traversal;
  lists = import ../../language/internal/lists.nix;
  inherit (lists) reverse;

  refuse = state: result.exhausted "nodes" state.limit state.consumed;
  spend =
    state:
    if state.remaining == 0 then
      {
        ok = false;
        failure = refuse state;
        inherit state;
      }
    else
      {
        ok = true;
        state = state // {
          remaining = state.remaining - 1;
          consumed = state.consumed + 1;
        };
      };
  invalid = kind: result.internalBug result.codes.invalidSemanticValue { inherit kind; };
  stale = result.internalBug result.codes.staleSemanticGeneration { };

  collectSpine =
    state: value:
    if !(builtins.isInt value.spineCount && value.spineCount >= 0) then
      {
        ok = false;
        failure = invalid "neutral-spine-count";
        inherit state;
      }
    else
      let
        final = transition.run {
          initial = {
            status = "running";
            remainingValues = value.spine;
            values = [ ];
            observed = 0;
            callerState = state;
            failure = null;
          };
          terminal = current: current.status != "running";
          step =
            current:
            let
              empty = builtins.tryEval (current.remainingValues == [ ]);
            in
            if !empty.success then
              current
              // {
                status = "failed";
                failure = invalid "neutral-spine";
              }
            else if empty.value then
              current
              // {
                status = if current.observed == value.spineCount then "done" else "failed";
                failure = if current.observed == value.spineCount then null else invalid "neutral-spine-count";
              }
            else
              let
                paid = spend current.callerState;
              in
              if !paid.ok then
                current
                // {
                  status = "failed";
                  inherit (paid) failure;
                }
              else
                let
                  observed = builtins.tryEval {
                    value = builtins.head current.remainingValues;
                    tail = builtins.tail current.remainingValues;
                  };
                in
                if !observed.success then
                  current
                  // {
                    status = "failed";
                    callerState = paid.state;
                    failure = invalid "neutral-spine";
                  }
                else
                  current
                  // {
                    remainingValues = observed.value.tail;
                    values = [ observed.value.value ] ++ current.values;
                    observed = current.observed + 1;
                    callerState = paid.state;
                  };
        };
      in
      if final.status == "failed" then
        {
          ok = false;
          inherit (final) failure;
          state = final.callerState;
        }
      else
        {
          ok = true;
          inherit (final) values;
          state = final.callerState;
        };

  collectEnvironment =
    state: environment:
    if !(builtins.isInt environment.nextLevel && environment.nextLevel >= 0) then
      {
        ok = false;
        failure = invalid "environment-next-level";
        inherit state;
      }
    else
      let
        final = transition.run {
          initial = {
            status = "running";
            position = 0;
            values = [ ];
            callerState = state;
            failure = null;
          };
          terminal = current: current.status != "running";
          step =
            current:
            if current.position == environment.nextLevel then
              current
              // {
                status = "done";
                values = reverse current.values;
              }
            else
              let
                level = current.position;
                key = representation.levelKey level;
              in
              if !(builtins.hasAttr key environment.cells) then
                current
                // {
                  status = "failed";
                  failure = result.internalBug result.codes.missingEnvironmentLevel { inherit level; };
                }
              else
                let
                  paid = spend current.callerState;
                in
                if !paid.ok then
                  current
                  // {
                    status = "failed";
                    inherit (paid) failure;
                  }
                else
                  current
                  // {
                    position = level + 1;
                    values = [
                      {
                        inherit level;
                        value = environment.cells.${key};
                      }
                    ]
                    ++ current.values;
                    callerState = paid.state;
                  };
        };
      in
      if final.status == "failed" then
        {
          ok = false;
          inherit (final) failure;
          state = final.callerState;
        }
      else
        {
          ok = true;
          inherit (final) values;
          state = final.callerState;
        };

  inspect =
    { frame, state }:
    let
      inherit (frame) tag;
      inherit (frame) value;
      generated = builtins.elem tag [
        "cell"
        "closure"
        "spine-item"
        "value"
      ];
      generationValid = !generated || representation.generationMatches value;
      paid =
        if frame.paid or false then
          {
            ok = true;
            inherit state;
          }
        else
          spend state;
      finish = kind: descriptor: children: nextState: {
        ok = true;
        inherit kind descriptor children;
        state = nextState;
      };
    in
    if !generationValid then
      {
        ok = false;
        failure = stale;
        inherit state;
      }
    else if tag == "environment" && !representation.generationMatches value then
      {
        ok = false;
        failure = stale;
        inherit state;
      }
    else if !paid.ok then
      paid
    else if tag == "term" then
      finish "term" value [ ] paid.state
    else if tag == "environment" then
      let
        cells = collectEnvironment paid.state value;
      in
      if !cells.ok then
        cells
      else
        finish "environment"
          {
            inherit (value) nextLevel;
            levels = map (entry: entry.level) cells.values;
          }
          (map (entry: {
            tag = "cell";
            inherit (entry) value;
            paid = true;
          }) cells.values)
          cells.state
    else if tag == "cell" then
      if value.kind == "value" then
        finish "cell-value" { } [
          {
            tag = "value";
            inherit (value) value;
          }
        ] paid.state
      else if value.kind == "thunk" then
        finish "cell-thunk" { } [
          {
            tag = "term";
            value = value.term;
          }
          {
            tag = "environment";
            value = value.environment;
            paid = true;
          }
        ] paid.state
      else
        {
          ok = false;
          failure = result.internalBug result.codes.invalidEnvironmentCell { kind = value.kind or null; };
          inherit (paid) state;
        }
    else if tag == "closure" then
      finish "closure" { } [
        {
          tag = "term";
          value = value.body;
        }
        {
          tag = "environment";
          value = value.environment;
          paid = true;
        }
      ] paid.state
    else if tag == "spine-item" then
      if value.kind == "application" then
        finish "spine-application" { } [
          {
            tag = "cell";
            value = value.argument;
          }
        ] paid.state
      else if
        builtins.elem value.kind [
          "first-projection"
          "second-projection"
        ]
      then
        finish "spine-leaf" { inherit (value) kind; } [ ] paid.state
      else if value.kind == "sum-elimination" then
        finish "spine-sum" { } [
          {
            tag = "closure";
            value = value.motive;
          }
          {
            tag = "closure";
            value = value.leftBranch;
          }
          {
            tag = "closure";
            value = value.rightBranch;
          }
        ] paid.state
      else if value.kind == "unit-elimination" then
        finish "spine-unit" { } [
          {
            tag = "closure";
            value = value.motive;
          }
          {
            tag = "cell";
            value = value.case;
          }
        ] paid.state
      else if value.kind == "empty-elimination" then
        finish "spine-empty" { } [
          {
            tag = "closure";
            value = value.motive;
          }
        ] paid.state
      else if value.kind == "identity-elimination" then
        finish "spine-identity" { } [
          {
            tag = "closure";
            value = value.motive;
          }
          {
            tag = "closure";
            value = value.reflBranch;
          }
        ] paid.state
      else
        {
          ok = false;
          failure = invalid (value.kind or null);
          inherit (paid) state;
        }
    else if tag == "value" then
      if value.kind == "neutral" then
        let
          items = collectSpine paid.state value;
        in
        if !items.ok then
          items
        else
          finish "value-neutral"
            {
              level = value.head.level;
              inherit (value) spineCount;
            }
            (map (item: {
              tag = "spine-item";
              value = item;
              paid = true;
            }) items.values)
            items.state
      else if value.kind == "closure" then
        finish "value-closure" { } [
          {
            tag = "closure";
            inherit value;
          }
        ] paid.state
      else if value.kind == "universe" then
        finish "value-universe" { inherit (value) level; } [ ] paid.state
      else if
        builtins.elem value.kind [
          "unit-type"
          "empty-type"
          "unit"
        ]
      then
        finish "value-leaf" { inherit (value) kind; } [ ] paid.state
      else if value.kind == "pi" || value.kind == "sigma" then
        finish "value-family" { inherit (value) kind; } [
          {
            tag = "cell";
            value = value.domain;
          }
          {
            tag = "closure";
            value = value.codomain;
          }
        ] paid.state
      else if value.kind == "sum-type" then
        finish "value-sum" { inherit (value) kind; } [
          {
            tag = "cell";
            value = value.left;
          }
          {
            tag = "cell";
            value = value.right;
          }
        ] paid.state
      else if value.kind == "pair" then
        finish "value-pair" { inherit (value) kind; } [
          {
            tag = "cell";
            value = value.first;
          }
          {
            tag = "cell";
            value = value.second;
          }
        ] paid.state
      else if
        builtins.elem value.kind [
          "left-injection"
          "right-injection"
          "refl"
        ]
      then
        finish "value-single" { inherit (value) kind; } [
          {
            tag = "cell";
            inherit (value) value;
          }
        ] paid.state
      else if value.kind == "identity-type" then
        finish "value-identity" { inherit (value) kind; } [
          {
            tag = "cell";
            value = value.carrier;
          }
          {
            tag = "cell";
            value = value.left;
          }
          {
            tag = "cell";
            value = value.right;
          }
        ] paid.state
      else
        {
          ok = false;
          failure = invalid (value.kind or null);
          inherit (paid) state;
        }
    else
      {
        ok = false;
        failure = invalid tag;
        inherit (paid) state;
      };

  reduce =
    {
      kind,
      descriptor,
      children,
      state,
    }:
    let
      child = index: builtins.elemAt children index;
      value =
        if kind == "term" then
          descriptor
        else if kind == "environment" then
          let
            pairs = builtins.genList (index: {
              name = toString (builtins.elemAt descriptor.levels index);
              value = {
                level = builtins.elemAt descriptor.levels index;
                cell = child index;
              };
            }) (builtins.length descriptor.levels);
            table = builtins.listToAttrs pairs;
          in
          {
            inherit (descriptor) nextLevel;
            cells = map (pair: table.${pair.name}) pairs;
          }
        else if kind == "cell-value" then
          {
            kind = "value";
            value = child 0;
          }
        else if kind == "cell-thunk" then
          {
            kind = "thunk";
            term = child 0;
            environment = child 1;
          }
        else if kind == "closure" then
          {
            body = child 0;
            environment = child 1;
          }
        else if kind == "spine-application" then
          {
            kind = "application";
            argument = child 0;
          }
        else if kind == "spine-leaf" then
          descriptor
        else if kind == "spine-sum" then
          {
            kind = "sum-elimination";
            motive = child 0;
            leftBranch = child 1;
            rightBranch = child 2;
          }
        else if kind == "spine-unit" then
          {
            kind = "unit-elimination";
            motive = child 0;
            case = child 1;
          }
        else if kind == "spine-empty" then
          {
            kind = "empty-elimination";
            motive = child 0;
          }
        else if kind == "spine-identity" then
          {
            kind = "identity-elimination";
            motive = child 0;
            reflBranch = child 1;
          }
        else if kind == "value-neutral" then
          {
            kind = "neutral";
            inherit (descriptor) level spineCount;
            spine = children;
          }
        else if kind == "value-closure" then
          {
            kind = "closure";
            inherit (child 0) body environment;
          }
        else if kind == "value-universe" then
          {
            kind = "universe";
            inherit (descriptor) level;
          }
        else if kind == "value-leaf" then
          descriptor
        else if kind == "value-family" then
          descriptor
          // {
            domain = child 0;
            codomain = child 1;
          }
        else if kind == "value-sum" then
          descriptor
          // {
            left = child 0;
            right = child 1;
          }
        else if kind == "value-pair" then
          descriptor
          // {
            first = child 0;
            second = child 1;
          }
        else if kind == "value-single" then
          descriptor // { value = child 0; }
        else if kind == "value-identity" then
          descriptor
          // {
            carrier = child 0;
            left = child 1;
            right = child 2;
          }
        else
          null;
    in
    if value == null then
      {
        ok = false;
        failure = invalid kind;
        inherit state;
      }
    else
      {
        ok = true;
        inherit value state;
      };

  projectValue =
    state: value:
    let
      folded = traversal.fold {
        kinds = [
          "cell-thunk"
          "cell-value"
          "closure"
          "environment"
          "spine-application"
          "spine-empty"
          "spine-identity"
          "spine-leaf"
          "spine-sum"
          "spine-unit"
          "term"
          "value-closure"
          "value-family"
          "value-identity"
          "value-leaf"
          "value-neutral"
          "value-pair"
          "value-single"
          "value-sum"
          "value-universe"
        ];
        root = {
          tag = "value";
          inherit value;
        };
        inherit state inspect reduce;
        invalidInventory = invalid "projection-inventory";
      };
      executed = computation.run {
        computation = folded;
        reader = null;
        state = null;
      };
    in
    if executed.kind == "failure" then
      {
        ok = false;
        inherit (executed) failure;
      }
    else
      {
        ok = true;
        value = executed.value.value;
        state = executed.value.callerState;
      };

  primitiveEqual = left: right: builtins.toJSON left == builtins.toJSON right;
  semanticEvents =
    trace:
    builtins.filter (
      event:
      builtins.elem event.kind [
        "charge"
        "lookup"
        "force"
        "closure"
        "closure-application"
        "neutral-application"
        "annotation-erased"
      ]
    ) trace;
  initial = limit: {
    remaining = limit;
    consumed = 0;
    inherit limit;
  };
in
{
  project =
    {
      value,
      limit ? 4096,
    }:
    projectValue (initial limit) value;
  equal =
    {
      left,
      right,
      limit ? 4096,
    }:
    let
      a = projectValue (initial limit) left;
      b = projectValue (initial limit) right;
    in
    a.ok && b.ok && primitiveEqual a.value b.value;
  traceEqual = left: right: primitiveEqual (semanticEvents left) (semanticEvents right);
  inherit semanticEvents primitiveEqual;
}
