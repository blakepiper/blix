{ ... }:

{
  programs.wiremix = {
    enable = true;
    # Distinguish outputs that share the same sound-card nickname.
    settings.names.endpoint = [
      "{node:node.nick}"
      "{node:node.description}"
      "{node:node.name}"
    ];
  };
}
