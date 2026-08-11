{ evaluation }:
let
  generation = "axiom-kernel-1";
  evaluationGeneration = evaluation.representation.generation;
  limits = {
    checking = 4096;
    conversion = 4096;
    comparison = 4096;
    readback = 4096;
    context = 256;
    output = 256;
    depth = 64;
  };
  exact =
    names: value:
    let
      checked = builtins.tryEval (builtins.isAttrs value && builtins.attrNames value == names);
    in
    checked.success && checked.value;
  generationMatches =
    value:
    let
      checked = builtins.tryEval (
        builtins.isAttrs value
        && value ? generation
        && builtins.isString value.generation
        && value.generation == generation
      );
    in
    checked.success && checked.value;
  semanticHeader =
    value:
    let
      outer = builtins.tryEval (builtins.isAttrs value);
    in
    if !outer.success || !outer.value then
      {
        ok = false;
        reason = "malformed";
      }
    else if
      !(value ? generation)
      || !builtins.isString value.generation
      || value.generation != evaluationGeneration
    then
      {
        ok = false;
        reason = "stale";
      }
    else if !(value ? kind) || !builtins.isString value.kind then
      {
        ok = false;
        reason = "malformed";
      }
    else
      {
        ok = true;
        inherit (value) kind;
      };
  semanticShape =
    value:
    let
      header = semanticHeader value;
      shapes = {
        neutral = [
          "generation"
          "head"
          "kind"
          "spine"
          "spineCount"
        ];
        closure = [
          "body"
          "environment"
          "generation"
          "kind"
        ];
        universe = [
          "generation"
          "kind"
          "level"
        ];
        pi = [
          "codomain"
          "domain"
          "generation"
          "kind"
        ];
        sigma = [
          "codomain"
          "domain"
          "generation"
          "kind"
        ];
        "sum-type" = [
          "generation"
          "kind"
          "left"
          "right"
        ];
        "unit-type" = [
          "generation"
          "kind"
        ];
        "empty-type" = [
          "generation"
          "kind"
        ];
        unit = [
          "generation"
          "kind"
        ];
        pair = [
          "first"
          "generation"
          "kind"
          "second"
        ];
        "left-injection" = [
          "generation"
          "kind"
          "value"
        ];
        "right-injection" = [
          "generation"
          "kind"
          "value"
        ];
        "identity-type" = [
          "carrier"
          "generation"
          "kind"
          "left"
          "right"
        ];
        refl = [
          "generation"
          "kind"
          "value"
        ];
      };
    in
    if !header.ok then
      header
    else if !(builtins.hasAttr header.kind shapes) || !exact shapes.${header.kind} value then
      {
        ok = false;
        reason = "malformed";
      }
    else
      {
        ok = true;
        inherit (header) kind;
      };
  cellShape =
    value:
    let
      header = semanticHeader value;
    in
    if !header.ok then
      header
    else if header.kind == "value" && exact [ "generation" "kind" "value" ] value then
      let
        child = semanticShape value.value;
      in
      if child.ok then
        {
          ok = true;
          kind = "value";
        }
      else
        child
    else if header.kind == "thunk" && exact [ "environment" "generation" "kind" "term" ] value then
      let
        environment = environmentShape value.environment;
      in
      if environment.ok then
        {
          ok = true;
          kind = "thunk";
        }
      else
        environment
    else
      {
        ok = false;
        reason = "malformed";
      };
  environmentShape =
    value:
    let
      outer = builtins.tryEval (builtins.isAttrs value);
    in
    if !outer.success || !outer.value then
      {
        ok = false;
        reason = "malformed";
      }
    else if
      !(value ? generation)
      || !builtins.isString value.generation
      || value.generation != evaluationGeneration
    then
      {
        ok = false;
        reason = "stale";
      }
    else if
      !exact [ "cells" "generation" "nextLevel" ] value
      || !builtins.isInt value.nextLevel
      || value.nextLevel < 0
      || !builtins.isAttrs value.cells
    then
      {
        ok = false;
        reason = "malformed";
      }
    else
      { ok = true; };
  neutralShape =
    value:
    let
      shaped = semanticShape value;
      observed = builtins.tryEval (
        shaped.ok
        && shaped.kind == "neutral"
        && exact [ "kind" "level" ] value.head
        && value.head.kind == "level"
        && builtins.isInt value.head.level
        && builtins.isList value.spine
        && builtins.isInt value.spineCount
        && value.spineCount >= 0
      );
    in
    if !shaped.ok then
      shaped
    else if !observed.success || !observed.value then
      {
        ok = false;
        reason = "malformed";
      }
    else
      { ok = true; };
  closureShape =
    value:
    let
      shaped = semanticShape value;
    in
    if !shaped.ok then
      shaped
    else if shaped.kind != "closure" then
      {
        ok = false;
        reason = "malformed";
      }
    else
      environmentShape value.environment;
  spineItemShape =
    value:
    let
      header = semanticHeader value;
      shapes = {
        application = [
          "argument"
          "generation"
          "kind"
        ];
        "first-projection" = [
          "generation"
          "kind"
        ];
        "second-projection" = [
          "generation"
          "kind"
        ];
        "sum-elimination" = [
          "generation"
          "kind"
          "leftBranch"
          "motive"
          "rightBranch"
        ];
        "unit-elimination" = [
          "case"
          "generation"
          "kind"
          "motive"
        ];
        "empty-elimination" = [
          "generation"
          "kind"
          "motive"
        ];
        "identity-elimination" = [
          "generation"
          "kind"
          "motive"
          "reflBranch"
        ];
      };
      payload =
        if !header.ok || !(builtins.hasAttr header.kind shapes) || !exact shapes.${header.kind} value then
          {
            ok = false;
            reason = "malformed";
          }
        else if header.kind == "application" then
          cellShape value.argument
        else if header.kind == "sum-elimination" then
          let
            motive = closureShape value.motive;
            left = closureShape value.leftBranch;
            right = closureShape value.rightBranch;
          in
          if !motive.ok then
            motive
          else if !left.ok then
            left
          else
            right
        else if header.kind == "unit-elimination" then
          let
            motive = closureShape value.motive;
          in
          if !motive.ok then motive else cellShape value.case
        else if header.kind == "empty-elimination" then
          closureShape value.motive
        else if header.kind == "identity-elimination" then
          let
            motive = closureShape value.motive;
          in
          if !motive.ok then motive else closureShape value.reflBranch
        else
          { ok = true; };
    in
    if !header.ok then
      header
    else if !payload.ok then
      payload
    else
      {
        ok = true;
        inherit (header) kind;
      };
  boundedNewestFirst =
    {
      value,
      count,
      limit,
    }:
    let
      outer = builtins.tryEval (builtins.isList value && builtins.isInt count && count >= 0);
      states =
        if !outer.success || !outer.value then
          [ ]
        else
          builtins.genericClosure {
            startSet = [
              {
                key = 0;
                status = "running";
                remaining = value;
                consumed = 0;
                oldest = [ ];
                failure = null;
              }
            ];
            operator =
              state:
              if state.status != "running" then
                [ ]
              else
                let
                  empty = builtins.tryEval (state.remaining == [ ]);
                  nextKey = state.key + 1;
                in
                if !empty.success then
                  [
                    (
                      state
                      // {
                        key = nextKey;
                        status = "done";
                        failure = "malformed";
                      }
                    )
                  ]
                else if empty.value then
                  [
                    (
                      state
                      // {
                        key = nextKey;
                        status = "done";
                        failure = if state.consumed == count then null else "count";
                      }
                    )
                  ]
                else if state.consumed >= limit then
                  [
                    (
                      state
                      // {
                        key = nextKey;
                        status = "done";
                        failure = "resource";
                      }
                    )
                  ]
                else
                  let
                    observed = builtins.tryEval (
                      let
                        item = builtins.head state.remaining;
                        tail = builtins.tail state.remaining;
                      in
                      builtins.seq item (builtins.seq tail { inherit item tail; })
                    );
                  in
                  if !observed.success then
                    [
                      (
                        state
                        // {
                          key = nextKey;
                          status = "done";
                          failure = "malformed";
                        }
                      )
                    ]
                  else
                    [
                      (
                        state
                        // {
                          key = nextKey;
                          consumed = state.consumed + 1;
                          remaining = observed.value.tail;
                          oldest = [ observed.value.item ] ++ state.oldest;
                        }
                      )
                    ];
          };
      final = if states == [ ] then null else builtins.elemAt states (builtins.length states - 1);
    in
    if !outer.success || !outer.value then
      {
        ok = false;
        reason = "malformed";
        consumed = 0;
      }
    else if final.failure != null then
      {
        ok = false;
        reason = final.failure;
        inherit (final) consumed;
      }
    else
      {
        ok = true;
        values = final.oldest;
        inherit (final) consumed;
      };
  semanticTreeShape =
    depth: value:
    let
      shaped = semanticShape value;
      cellTree =
        cell:
        let
          checked = cellShape cell;
        in
        checked.ok && (cell.kind != "value" || semanticTreeShape (depth + 1) cell.value);
      closureTree = closure: (closureShape closure).ok;
      children =
        if !shaped.ok || depth > limits.depth then
          false
        else if shaped.kind == "pi" || shaped.kind == "sigma" then
          cellTree value.domain && closureTree value.codomain
        else if shaped.kind == "sum-type" then
          cellTree value.left && cellTree value.right
        else if shaped.kind == "identity-type" then
          cellTree value.carrier && cellTree value.left && cellTree value.right
        else if shaped.kind == "pair" then
          cellTree value.first && cellTree value.second
        else if
          shaped.kind == "left-injection" || shaped.kind == "right-injection" || shaped.kind == "refl"
        then
          cellTree value.value
        else if shaped.kind == "closure" then
          closureTree value
        else if shaped.kind == "neutral" then
          let
            neutral = neutralShape value;
            spine =
              if neutral.ok then
                boundedNewestFirst {
                  value = value.spine;
                  count = value.spineCount;
                  limit = limits.readback;
                }
              else
                { ok = false; };
          in
          neutral.ok && spine.ok && builtins.all (item: (spineItemShape item).ok) spine.values
        else
          true;
    in
    shaped.ok && depth <= limits.depth && children;
  contextEntryShape =
    level: entry:
    let
      checked = builtins.tryEval (
        generationMatches entry
        && exact [ "generation" "kind" "level" "type" ] entry
        && entry.kind == "context-entry"
        && builtins.isInt entry.level
        && entry.level == level
        && semanticTreeShape 0 entry.type
      );
    in
    checked.success && checked.value;
  contextShape =
    value:
    let
      checked = builtins.tryEval (
        generationMatches value
        && exact [ "depth" "entries" "entryCount" "environment" "generation" "kind" ] value
        && value.kind == "context"
        && builtins.isInt value.depth
        && value.depth >= 0
        && value.depth <= limits.context
        && value.depth <= limits.depth
        && builtins.isInt value.entryCount
        && value.entryCount == value.depth
        && (environmentShape value.environment).ok
        && value.environment.nextLevel == value.depth
        && builtins.isAttrs value.entries
        &&
          builtins.attrNames value.entries
          == builtins.sort builtins.lessThan (builtins.genList toString value.depth)
        && builtins.all (level: contextEntryShape level value.entries.${toString level}) (
          builtins.genList (x: x) value.depth
        )
      );
    in
    checked.success && checked.value;
  contextEntry = level: type: {
    inherit generation level type;
    kind = "context-entry";
  };
  context = depth: environment: entries: {
    inherit
      generation
      depth
      environment
      entries
      ;
    kind = "context";
    entryCount = depth;
  };
  resources = values: {
    checking = values.checking or 0;
    conversion = values.conversion or 0;
    comparison = values.comparison or 0;
    readback = values.readback or 0;
    context = values.context or 0;
    output = values.output or 0;
    depth = values.depth or 0;
  };
  validResources =
    value:
    exact [
      "checking"
      "comparison"
      "context"
      "conversion"
      "depth"
      "output"
      "readback"
    ] value
    && builtins.all (name: builtins.isInt value.${name} && value.${name} >= 0) (
      builtins.attrNames value
    );
in
{
  inherit
    generation
    evaluationGeneration
    limits
    exact
    generationMatches
    semanticHeader
    semanticShape
    cellShape
    environmentShape
    neutralShape
    closureShape
    spineItemShape
    boundedNewestFirst
    semanticTreeShape
    contextEntryShape
    contextShape
    contextEntry
    context
    resources
    validResources
    ;
}
