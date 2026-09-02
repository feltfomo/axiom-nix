{
  identity = "kernel-transition-wrong-advance";
  select =
    { computation }:
    baseAdvance: descriptor:
    computation.map (
      next: if descriptor.item.kind == "application" then next // { inherit (descriptor) type; } else next
    ) (baseAdvance descriptor);
}
