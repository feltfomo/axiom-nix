{ representation, traversal }:
let
  inherit (representation) generation limits;
  attrs = import ../internal/attrs.nix;
  inherit (attrs) exact;
  pathKey = path: "$/${builtins.concatStringsSep "/" path}";
  rejected = kind: detail: {
    ok = false;
    inherit kind detail;
  };

  lists = import ../internal/lists.nix;
  inherit (lists) reverse;
  worklist = import ../internal/worklist.nix { inherit lists; };
  spine = import ../internal/spine.nix { inherit worklist; };
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
      folded = spine.fold {
        inherit value limit;
        initial = [ ];
        consume = values: item: [ item ] ++ values;
      };
    in
    if !folded.ok && folded.reason == "resource" then
      resourceExhausted channel dimension limit folded.consumed
    else if !folded.ok && folded.reason == "malformed-spine" then
      rejected "host-failure" "${channel}-spine"
    else if !folded.ok then
      rejected "host-failure" "${channel}-component"
    else
      {
        ok = true;
        values = reverse folded.accumulator;
        inherit (folded) consumed;
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
        checked = traversal.validate {
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

  rewriteOperation =
    {
      source,
      targetScope,
      variableAction,
      metadataTransform,
    }:
    let
      rewritten = traversal.rewrite {
        inherit (source) root;
        inherit (source) scope;
        onVariable = variableAction;
      };
    in
    if !rewritten.ok then rewritten else finish targetScope (metadataTransform rewritten) rewritten;

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
      rewriteOperation {
        source = source.value;
        inherit targetScope;
        variableAction = { node, ... }: mapFree envelope.scope targetScope prepared.table node;
        metadataTransform = _result: source.value.metadata;
      };

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
      rewriteOperation {
        source = source.value;
        inherit targetScope;
        variableAction =
          { node, ... }:
          if node.level < envelope.scope then
            prepared.table.${toString node.level}.root
          else
            representation.variable (node.level + targetScope - envelope.scope);
        metadataTransform =
          rewritten:
          let
            occurrences = builtins.filter (occurrence: occurrence.level < envelope.scope) rewritten.variables;
          in
          spliceMetadata source.value.metadata occurrences prepared.table;
      };

  open =
    { envelope, replacement }:
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
        subject = {
          root = source.value.root.body;
          scope = scope + 1;
          metadata = unprefixBody source.value.metadata;
        };
        replacementMap = {
          ${toString scope} = {
            root = replacementResult.value.root;
            metadata = replacementResult.value.metadata;
          };
        };
      in
      rewriteOperation {
        source = subject;
        targetScope = scope;
        variableAction =
          { node, ... }:
          if node.level == scope then
            replacementResult.value.root
          else if node.level > scope then
            representation.variable (node.level - 1)
          else
            representation.variable node.level;
        metadataTransform =
          rewritten:
          let
            occurrences = builtins.filter (occurrence: occurrence.level == scope) rewritten.variables;
          in
          spliceMetadata subject.metadata occurrences replacementMap;
      };

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
      binder = canonicalizeMetadata {
        metadata = [ binderMetadata ];
        validPaths = [ [ ] ];
      };
      rewritten =
        if !source.ok || !(builtins.isInt sourceLevel && sourceLevel >= 0 && sourceLevel < scope) then
          rejected "boundary-mismatch" "closing-level"
        else
          rewriteOperation {
            source = source.value;
            targetScope = scope + 1;
            variableAction =
              { node, ... }:
              representation.variable (
                if node.level == sourceLevel then
                  scope
                else if node.level >= scope then
                  node.level + 1
                else
                  node.level
              );
            metadataTransform = _result: source.value.metadata;
          };
    in
    if !source.ok then
      source
    else if !(builtins.isInt sourceLevel && sourceLevel >= 0 && sourceLevel < scope) then
      rejected "boundary-mismatch" "closing-level"
    else if !binder.ok then
      binder
    else if !rewritten.ok then
      rewritten
    else
      admitted (
        representation.envelope scope (representation.lambda rewritten.value.root) (
          binder.metadata ++ prefixMetadata [ "body" ] rewritten.value.metadata
        )
      );
  # binder bodies use one ordered consecutive segment above the unchanged outer scope
  closeBinderBody =
    { envelope, sourceLevels }:
    let
      source = admitted envelope;
      observedOuter = builtins.tryEval (builtins.isList sourceLevels);
      outerValid = observedOuter.success && observedOuter.value;
      observedMembers =
        if outerValid then
          builtins.tryEval (
            builtins.all (level: builtins.isInt level && level >= 0 && level < envelope.scope) sourceLevels
          )
        else
          {
            success = true;
            value = false;
          };
    in
    if !source.ok || !outerValid || !observedMembers.success || !observedMembers.value then
      rejected "boundary-mismatch" "binder-close"
    else
      let
        count = builtins.length sourceLevels;
        keys = map toString sourceLevels;
        unique =
          builtins.length (
            builtins.attrNames (
              builtins.listToAttrs (
                map (name: {
                  inherit name;
                  value = true;
                }) keys
              )
            )
          ) == count;
        positions = builtins.listToAttrs (
          builtins.genList (index: {
            name = builtins.elemAt keys index;
            value = index;
          }) count
        );
      in
      if !unique then
        rejected "boundary-mismatch" "binder-close"
      else
        rewriteOperation {
          source = source.value;
          targetScope = envelope.scope + count;
          variableAction =
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
          metadataTransform = _result: source.value.metadata;
        };

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
    in
    if !valid then
      rejected "boundary-mismatch" "binder-open"
    else
      rewriteOperation {
        source = source.value;
        targetScope = outerScope;
        variableAction =
          { node, ... }:
          if node.level < outerScope then
            representation.variable node.level
          else if node.level < outerScope + count then
            prepared.table.${toString (node.level - outerScope)}.root
          else
            representation.variable (node.level - count);
        metadataTransform = _result: source.value.metadata;
      };

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
    # admitted roots are closed first-order core values and metadata is outside this comparison
    && a.value.root == b.value.root;
}
