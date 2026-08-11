{ representation, machine }:
let
  inherit (representation) generation limits;
  exact = names: value: builtins.isAttrs value && builtins.attrNames value == names;
  pathKey = path: "$/${builtins.concatStringsSep "/" path}";
  rejected = kind: detail: {
    ok = false;
    inherit kind detail;
  };

  reverse = builtins.foldl' (values: value: [ value ] ++ values) [ ];
  resourceExhausted = channel: dimension: limit: consumed: {
    ok = false;
    kind = "resource-exhaustion";
    inherit
      channel
      dimension
      limit
      consumed
      ;
  };

  boundedSpine =
    {
      value,
      limit,
      channel,
      dimension,
    }:
    let
      outer = builtins.tryEval (builtins.isList value);
    in
    if !outer.success then
      rejected "host-failure" "${channel}-spine"
    else if !outer.value then
      rejected "boundary-mismatch" "${channel}-list"
    else
      let
        states = builtins.genericClosure {
          startSet = [
            {
              key = 0;
              status = "running";
              consumed = 0;
              remaining = value;
              values = [ ];
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
                      failure = rejected "host-failure" "${channel}-spine";
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
                      failure = resourceExhausted channel dimension limit state.consumed;
                    }
                  )
                ]
              else
                let
                  observed = builtins.tryEval (
                    let
                      item = builtins.head state.remaining;
                      remaining = builtins.tail state.remaining;
                    in
                    builtins.seq item (builtins.seq remaining { inherit item remaining; })
                  );
                in
                if !observed.success then
                  [
                    (
                      state
                      // {
                        key = nextKey;
                        status = "done";
                        failure = rejected "host-failure" "${channel}-component";
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
                        remaining = observed.value.remaining;
                        values = [ observed.value.item ] ++ state.values;
                      }
                    )
                  ];
        };
        final = builtins.elemAt states (builtins.length states - 1);
      in
      if final.failure != null then
        final.failure
      else
        {
          ok = true;
          values = reverse final.values;
          inherit (final) consumed;
        };

  normalizeMetadataEntry =
    entry:
    let
      outer = builtins.tryEval (builtins.typeOf entry);
    in
    if !outer.success then
      rejected "host-failure" "metadata-entry-outer"
    else if outer.value != "set" then
      rejected "boundary-mismatch" "metadata-entry"
    else
      let
        shape = builtins.tryEval (exact [ "location" "name" "path" ] entry);
      in
      if !shape.success then
        rejected "host-failure" "metadata-entry-shape"
      else if !shape.value then
        rejected "boundary-mismatch" "metadata-entry"
      else
        let
          path = boundedSpine {
            value = entry.path;
            limit = limits.depth;
            channel = "metadata-path";
            dimension = "depth";
          };
          location = boundedSpine {
            value = entry.location;
            limit = limits.locationComponents;
            channel = "metadata-location";
            dimension = "nodes";
          };
          name = builtins.tryEval (entry.name == null || builtins.isString entry.name);
        in
        if !path.ok then
          path
        else if !builtins.all builtins.isString path.values then
          rejected "boundary-mismatch" "metadata-path-component"
        else if !location.ok then
          location
        else if !builtins.all (part: builtins.isString part || builtins.isInt part) location.values then
          rejected "boundary-mismatch" "metadata-location-component"
        else if !name.success then
          rejected "host-failure" "metadata-name"
        else if !name.value then
          rejected "boundary-mismatch" "metadata-name"
        else
          {
            ok = true;
            value = {
              path = path.values;
              inherit (entry) name;
              location = location.values;
            };
          };

  canonicalizeMetadata =
    { metadata, validPaths }:
    let
      spine = boundedSpine {
        value = metadata;
        limit = limits.nodes;
        channel = "metadata";
        dimension = "nodes";
      };
    in
    if !spine.ok then
      spine
    else
      let
        validPathMap = builtins.listToAttrs (
          map (path: {
            name = pathKey path;
            value = path;
          }) validPaths
        );
        collected =
          builtins.foldl'
            (
              state: entry:
              if !state.ok then
                state
              else
                let
                  normalized = normalizeMetadataEntry entry;
                in
                if !normalized.ok then
                  {
                    ok = false;
                    failure = normalized;
                    inherit (state) entries;
                  }
                else
                  let
                    key = pathKey normalized.value.path;
                  in
                  if !(builtins.hasAttr key validPathMap) || validPathMap.${key} != normalized.value.path then
                    {
                      ok = false;
                      failure = rejected "boundary-mismatch" "metadata-path";
                      inherit (state) entries;
                    }
                  else if builtins.hasAttr key state.entries then
                    {
                      ok = false;
                      failure = rejected "boundary-mismatch" "metadata-duplicate";
                      inherit (state) entries;
                    }
                  else
                    {
                      ok = true;
                      failure = null;
                      entries = state.entries // {
                        ${key} = normalized.value;
                      };
                    }
            )
            {
              ok = true;
              failure = null;
              entries = { };
            }
            spine.values;
        ordered = builtins.filter (entry: entry != null) (
          map (
            path:
            let
              key = pathKey path;
            in
            if builtins.hasAttr key collected.entries then collected.entries.${key} else null
          ) validPaths
        );
      in
      if !collected.ok then
        collected.failure
      else
        {
          ok = true;
          metadata = ordered;
        };

  admitted =
    envelope:
    if !exact [ "generation" "metadata" "root" "scope" ] envelope then
      rejected "boundary-mismatch" "envelope"
    else if envelope.generation != generation then
      rejected "boundary-mismatch" "generation"
    else if !(builtins.isInt envelope.scope && envelope.scope >= 0) then
      rejected "boundary-mismatch" "scope"
    else
      let
        checked = machine.validate {
          inherit (envelope) root scope;
        };
      in
      if !checked.ok then
        checked
      else
        let
          metadata = canonicalizeMetadata {
            inherit (envelope) metadata;
            validPaths = checked.paths;
          };
        in
        if !metadata.ok then
          metadata
        else
          {
            ok = true;
            value = representation.envelope envelope.scope checked.value metadata.metadata;
            nodes = checked.consumed;
            inherit (checked) paths variables;
          };

  finish =
    scope: metadata: rewritten:
    if !rewritten.ok then
      rewritten
    else
      admitted (representation.envelope scope rewritten.value metadata);

  prepareMap =
    sourceScope: targetScope: injective: mapping:
    let
      checked = builtins.tryEval (
        if
          !builtins.isInt targetScope
          || targetScope < 0
          || !builtins.isList mapping
          || builtins.length mapping != sourceScope
        then
          {
            ok = false;
            detail = "scope-map";
          }
        else
          builtins.foldl'
            (
              state: target:
              if !state.ok then
                state
              else if
                !builtins.isInt target
                || target < 0
                || target >= targetScope
                || (injective && state.previous != null && state.previous >= target)
              then
                state
                // {
                  ok = false;
                  detail = "scope-map";
                }
              else
                {
                  ok = true;
                  detail = null;
                  index = state.index + 1;
                  previous = target;
                  table = state.table // {
                    ${toString state.index} = target;
                  };
                }
            )
            {
              ok = true;
              detail = null;
              index = 0;
              previous = null;
              table = { };
            }
            mapping
      );
    in
    if !checked.success then rejected "host-failure" "scope-map-control" else checked.value;

  # bound levels move by the scope delta while free levels use the prepared map
  mapFree =
    sourceScope: targetScope: table: node:
    if node.level < sourceScope then
      representation.variable table.${toString node.level}
    else
      representation.variable (node.level + targetScope - sourceScope);

  transformMap =
    {
      envelope,
      targetScope,
      mapping,
      injective,
    }:
    let
      source = admitted envelope;
      prepared =
        if source.ok then
          prepareMap envelope.scope targetScope injective mapping
        else
          rejected "boundary-mismatch" "source";
    in
    if !source.ok then
      source
    else if !prepared.ok then
      prepared
    else
      finish targetScope source.value.metadata (
        machine.rewrite {
          root = source.value.root;
          inherit (envelope) scope;
          onVariable =
            { node, ... }:
            mapFree envelope.scope targetScope prepared.table node;
        }
      );

  prefixMetadata = prefix: metadata: map (entry: entry // { path = prefix ++ entry.path; }) metadata;
  unprefixBody =
    metadata:
    map (entry: entry // { path = builtins.tail entry.path; }) (
      builtins.filter (entry: entry.path != [ ] && builtins.head entry.path == "body") metadata
    );

  # inserted syntax owns metadata beneath each replaced variable path
  spliceMetadata =
    subjectMetadata: occurrences: replacementMap:
    let
      kept = builtins.filter (
        entry: !(builtins.any (occurrence: occurrence.path == entry.path) occurrences)
      ) subjectMetadata;
      inserted = builtins.concatLists (
        map (
          occurrence: prefixMetadata occurrence.path replacementMap.${toString occurrence.level}.metadata
        ) occurrences
      );
    in
    kept ++ inserted;

  prepareReplacements =
    targetScope: replacements:
    let
      checked = builtins.tryEval (
        if !builtins.isList replacements then
          {
            ok = false;
            detail = "substitution";
          }
        else
          builtins.foldl'
            (
              state: replacement:
              if !state.ok then
                state
              else
                let
                  item = admitted replacement;
                in
                if !item.ok || item.value.scope != targetScope then
                  state
                  // {
                    ok = false;
                    detail = "substitution";
                  }
                else
                  {
                    ok = true;
                    detail = null;
                    index = state.index + 1;
                    table = state.table // {
                      ${toString state.index} = {
                        root = item.value.root;
                        metadata = item.value.metadata;
                      };
                    };
                  }
            )
            {
              ok = true;
              detail = null;
              index = 0;
              table = { };
            }
            replacements
      );
    in
    if !checked.success then rejected "host-failure" "substitution-control" else checked.value;

  substitute =
    {
      envelope,
      replacements,
      targetScope,
    }:
    let
      source = admitted envelope;
      prepared = prepareReplacements targetScope replacements;
    in
    if !source.ok then
      source
    else if !prepared.ok || prepared.index != envelope.scope then
      rejected "boundary-mismatch" "substitution"
    else
      let
        rewritten = machine.rewrite {
          root = source.value.root;
          inherit (envelope) scope;
          onVariable =
            { node, ... }:
            if node.level < envelope.scope then
              prepared.table.${toString node.level}.root
            else
              representation.variable (node.level + targetScope - envelope.scope);
        };
        occurrences = builtins.filter (occurrence: occurrence.level < envelope.scope) rewritten.variables;
        metadata = spliceMetadata source.value.metadata occurrences prepared.table;
      in
      finish targetScope metadata rewritten;

  open =
    {
      envelope,
      replacement,
    }:
    let
      source = admitted envelope;
      replacementResult = admitted replacement;
      inherit (envelope) scope;
    in
    if !source.ok then
      source
    else if !replacementResult.ok || replacement.scope != scope then
      rejected "boundary-mismatch" "opening-replacement"
    else if source.value.root.kind != "lambda" then
      rejected "boundary-mismatch" "opening-lambda"
    else
      let
        rewritten = machine.rewrite {
          root = source.value.root.body;
          scope = scope + 1;
          onVariable =
            { node, ... }:
            if node.level == scope then
              replacementResult.value.root
            else if node.level > scope then
              representation.variable (node.level - 1)
            else
              representation.variable node.level;
        };
        occurrences = builtins.filter (occurrence: occurrence.level == scope) rewritten.variables;
        replacementMap = {
          ${toString scope} = {
            root = replacementResult.value.root;
            metadata = replacementResult.value.metadata;
          };
        };
        metadata = spliceMetadata (unprefixBody source.value.metadata) occurrences replacementMap;
      in
      finish scope metadata rewritten;

  close =
    {
      envelope,
      sourceLevel,
      binderMetadata ? {
        path = [ ];
        name = null;
        location = [ ];
      },
    }:
    let
      source = admitted envelope;
      inherit (envelope) scope;
    in
    if !source.ok then
      source
    else if !(builtins.isInt sourceLevel && sourceLevel >= 0 && sourceLevel < scope) then
      rejected "boundary-mismatch" "closing-level"
    else
      let
        binder = canonicalizeMetadata {
          metadata = [ binderMetadata ];
          validPaths = [ [ ] ];
        };
        rewritten = machine.rewrite {
          root = source.value.root;
          inherit scope;
          onVariable =
            { node, ... }:
            representation.variable (
              if node.level == sourceLevel then
                scope
              else if node.level >= scope then
                node.level + 1
              else
                node.level
            );
        };
      in
      if !binder.ok then
        binder
      else if !rewritten.ok then
        rewritten
      else
        admitted (
          representation.envelope scope (representation.lambda rewritten.value) (
            binder.metadata ++ prefixMetadata [ "body" ] source.value.metadata
          )
        );
  # binder bodies use one ordered consecutive segment above the unchanged outer scope
  closeBinderBody =
    { envelope, sourceLevels }:
    let
      source = admitted envelope;
      count = if builtins.isList sourceLevels then builtins.length sourceLevels else -1;
      unique =
        builtins.length (
          builtins.attrNames (
            builtins.listToAttrs (
              map (level: {
                name = toString level;
                value = true;
              }) sourceLevels
            )
          )
        ) == count;
      valid =
        source.ok
        && count >= 0
        && unique
        && builtins.all (level: builtins.isInt level && level >= 0 && level < envelope.scope) sourceLevels;
      positions = builtins.listToAttrs (
        builtins.genList (index: {
          name = toString (builtins.elemAt sourceLevels index);
          value = index;
        }) count
      );
      rewritten =
        if !valid then
          rejected "boundary-mismatch" "binder-close"
        else
          machine.rewrite {
            root = source.value.root;
            inherit (envelope) scope;
            onVariable =
              { node, ... }:
              let
                key = toString node.level;
              in
              if node.level < envelope.scope && builtins.hasAttr key positions then
                representation.variable (envelope.scope + positions.${key})
              else if node.level >= envelope.scope then
                representation.variable (node.level + count)
              else
                representation.variable node.level;
          };
    in
    if !valid then
      rejected "boundary-mismatch" "binder-close"
    else if !rewritten.ok then
      rewritten
    else
      admitted (representation.envelope (envelope.scope + count) rewritten.value source.value.metadata);

  openBinderBody =
    {
      envelope,
      outerScope,
      replacements,
    }:
    let
      source = admitted envelope;
      count = if builtins.isList replacements then builtins.length replacements else -1;
      prepared =
        if count < 0 then
          rejected "boundary-mismatch" "binder-open"
        else
          prepareReplacements outerScope replacements;
      valid =
        source.ok
        && builtins.isInt outerScope
        && outerScope >= 0
        && envelope.scope == outerScope + count
        && prepared.ok
        && prepared.index == count;
      rewritten =
        if !valid then
          rejected "boundary-mismatch" "binder-open"
        else
          machine.rewrite {
            root = source.value.root;
            inherit (envelope) scope;
            onVariable =
              { node, ... }:
              if node.level < outerScope then
                representation.variable node.level
              else if node.level < outerScope + count then
                prepared.table.${toString (node.level - outerScope)}.root
              else
                representation.variable (node.level - count);
          };
    in
    if !valid then
      rejected "boundary-mismatch" "binder-open"
    else
      finish outerScope source.value.metadata rewritten;

in
{
  inherit
    admitted
    canonicalizeMetadata
    substitute
    open
    close
    closeBinderBody
    openBinderBody
    ;
  weaken = args: transformMap (args // { injective = true; });
  rename = args: transformMap (args // { injective = false; });
  structurallyEqual =
    left: right:
    let
      a = admitted left;
      b = admitted right;
    in
    a.ok
    && b.ok
    && a.value.scope == b.value.scope
    && machine.equal {
      left = a.value.root;
      right = b.value.root;
      scope = a.value.scope;
    };
}
