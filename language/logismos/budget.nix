{ computation }:
{
  make =
    {
      dimensions,
      namedCosts,
    }:
    let
      zero = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = 0;
        }) dimensions
      );
      valid =
        vector:
        builtins.attrNames vector == builtins.sort builtins.lessThan dimensions
        && builtins.all (name: builtins.isInt vector.${name} && vector.${name} >= 0) dimensions;
      add =
        left: right:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = left.${name} + right.${name};
          }) dimensions
        );
      lessOrEqual = left: right: builtins.all (name: left.${name} <= right.${name}) dimensions;
      # subtraction is only defined inside the limit, so capacity never goes negative
      remaining =
        limit: usage:
        if lessOrEqual usage limit then
          builtins.listToAttrs (
            map (name: {
              inherit name;
              value = limit.${name} - usage.${name};
            }) dimensions
          )
        else
          null;
      charge =
        {
          limit,
          usage,
          cost,
          refusal,
        }:
        let
          next = add usage cost;
        in
        # a refused charge never opens the continuation that owns the protected value
        if lessOrEqual next limit then computation.pure next else computation.fail refusal;
      maximumDepth =
        usage: depth:
        usage
        // {
          depth = if depth > usage.depth then depth else usage.depth;
        };
    in
    {
      inherit
        zero
        valid
        add
        lessOrEqual
        remaining
        charge
        maximumDepth
        namedCosts
        ;
    };
}
