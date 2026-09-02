{
  identity = "kernel-transition-drop-argument";
  select =
    { computation }:
    baseAdvance: descriptor:
    computation.map (
      next:
      if descriptor.item.kind == "application" then
        next
        // {
          inherit (descriptor) value;
          peerValue = if descriptor.paired then descriptor.peerValue else null;
        }
      else
        next
    ) (baseAdvance descriptor);
}
