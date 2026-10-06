{ ... }:

{
  programs.git = {
    enable = true;
    settings.user = {
      name = "Blake Piper";
      email = "blakepiper47@gmail.com";
    };
    # Use SSH for GitHub pulls and pushes, including HTTPS clone URLs.
    settings.url."git@github.com:".insteadOf = "https://github.com/";
  };
}
