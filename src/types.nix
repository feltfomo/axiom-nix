{
  lib,
  validation,
  schema,
  tagged,
  sets,
}:
let
  checkedType =
    type:
    if
      builtins.isAttrs type
      && builtins.isString (type.name or null)
      && builtins.isFunction (type.validate or null)
      && type ? description
    then
      type
    else
      throw "axiom: types expected a runtime type description";

  mk = name: description: validate: {
    inherit name description validate;
    check = value: validation.isSuccess (validate value);
  };

  issue = path: expected: actual: reason: {
    inherit
      path
      expected
      actual
      reason
      ;
  };
  rejected = name: value: validation.failure [ (issue [ ] name (builtins.typeOf value) "type") ];
  prefix = path: validation.mapDiagnostics (problem: problem // { path = path ++ problem.path; });

  primitive =
    name: predicate:
    mk name { kind = name; } (
      value: if predicate value then validation.success value else rejected name value
    );
  opaque = mk "opaque" { kind = "opaque"; } validation.success;
  string = primitive "string" builtins.isString;
  int = primitive "int" builtins.isInt;
  float = primitive "float" builtins.isFloat;
  bool = primitive "bool" builtins.isBool;
  path = primitive "path" builtins.isPath;
  function = primitive "function" builtins.isFunction;
  attrs = primitive "set" builtins.isAttrs;
  list = primitive "list" builtins.isList;

  listOf =
    type:
    let
      element = checkedType type;
      name = "list of ${element.name}";
    in
    mk name
      {
        kind = "list";
        element = element.description;
      }
      (
        value:
        builtins.seq element (
          if !builtins.isList value then
            rejected name value
          else
            validation.sequence (lib.imap0 (i: item: prefix [ i ] (element.validate item)) value)
        )
      );

  attrsOf =
    type:
    let
      element = checkedType type;
      name = "attributes of ${element.name}";
    in
    mk name
      {
        kind = "attrs";
        element = element.description;
      }
      (
        value:
        builtins.seq element (
          if !builtins.isAttrs value then
            rejected name value
          else
            validation.traverseAttrs (key: item: prefix [ key ] (element.validate item)) value
        )
      );

  record =
    fields:
    let
      checked =
        if builtins.isAttrs fields then
          lib.mapAttrs (_: checkedType) fields
        else
          throw "axiom: record types require an attribute set of fields";
      parse = schema.compile {
        fields = lib.mapAttrs (key: type: {
          required = true;
          parse = value: prefix [ key ] (type.validate value);
          onMissing = _: issue [ key ] type.name "missing" "missing-field";
        }) checked;
        onRecord = value: issue [ ] "record" (builtins.typeOf value) "type";
        onUnknown = key: _: issue [ key ] "declared field" "unknown" "unknown-field";
      };
    in
    mk "record" {
      kind = "record";
      fields = lib.mapAttrs (_: type: type.description) checked;
    } parse;

  nullOr =
    type:
    let
      element = checkedType type;
    in
    mk "null or ${element.name}"
      {
        kind = "nullable";
        element = element.description;
      }
      (
        value:
        builtins.seq element (if value == null then validation.success null else element.validate value)
      );

  enum =
    values:
    let
      allowed = sets.unique values;
      name = "one of ${lib.concatStringsSep ", " (map builtins.toJSON allowed)}";
      members = sets.index allowed;
    in
    if allowed == [ ] then
      throw "axiom: enum types require at least one string"
    else
      mk name
        {
          kind = "enum";
          values = allowed;
        }
        (
          value:
          if builtins.isString value && builtins.hasAttr value members then
            validation.success value
          else
            rejected name value
        );

  refine =
    name: type: predicate:
    let
      base = checkedType type;
    in
    if !builtins.isString name || name == "" then
      throw "axiom: refinement name must be a non-empty string"
    else if !builtins.isFunction predicate then
      throw "axiom: refinement predicate must be a function"
    else
      mk name
        {
          kind = "refinement";
          inherit name;
          base = base.description;
        }
        (
          value:
          validation.andThen (
            parsed:
            if predicate parsed then
              validation.success parsed
            else
              validation.failure [ (issue [ ] name (builtins.typeOf parsed) "refinement") ]
          ) (base.validate value)
        );

  oneOf =
    name: alternatives:
    if !builtins.isString name || name == "" then
      throw "axiom: alternative name must be a non-empty string"
    else if !builtins.isList alternatives || alternatives == [ ] then
      throw "axiom: oneOf requires a non-empty list of runtime types"
    else
      let
        choose =
          value: remaining:
          let
            result = (checkedType (builtins.head remaining)).validate value;
            rest = builtins.tail remaining;
          in
          if validation.isSuccess result || rest == [ ] then
            result
          else
            let
              next = choose value rest;
            in
            if validation.isSuccess next then
              next
            else
              validation.failure (result.diagnostics ++ next.diagnostics);
      in
      mk name {
        kind = "alternatives";
        inherit name;
        alternatives = map (type: (checkedType type).description) alternatives;
      } (value: choose value alternatives);

  variant =
    cases:
    if !builtins.isAttrs cases || cases == { } || builtins.hasAttr "" cases then
      throw "axiom: variant types require non-empty named cases"
    else
      mk "tagged variant"
        {
          kind = "variant";
          cases = lib.mapAttrs (_: type: (checkedType type).description) cases;
        }
        (
          value:
          if !tagged.isTagged value then
            rejected "tagged variant" value
          else if !builtins.isString value.tag then
            validation.failure [ (issue [ "tag" ] "string" (builtins.typeOf value.tag) "type") ]
          else if !(builtins.hasAttr value.tag cases) then
            validation.failure [ (issue [ "tag" ] "declared variant" "string" "unknown-variant") ]
          else
            validation.map (tagged.mk value.tag) (
              prefix [ "value" ] ((checkedType cases.${value.tag}).validate value.value)
            )
        );
in
{
  inherit
    opaque
    string
    int
    float
    bool
    path
    function
    attrs
    list
    listOf
    attrsOf
    record
    nullOr
    enum
    refine
    oneOf
    variant
    ;
}
