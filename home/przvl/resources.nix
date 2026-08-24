{ pkgs }:

{
  icons = {
    aiUsage = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/lucide-icons/lucide/59978cecf84986af59f1f9f503bcebdc89c6d166/icons/sparkles.svg";
      hash = "sha256-9UmfM/CdcVgVHpvS7A+vef+PtXKS+E/dcobZbQ8EJNg=";
    };
    theme = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/lucide-icons/lucide/59978cecf84986af59f1f9f503bcebdc89c6d166/icons/palette.svg";
      hash = "sha256-jn0/3pkM/9EEabo1HyfFAgKwV6m7mvViYyLlP9Orx4w=";
    };
    night = {
      on = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/lucide-icons/lucide/59978cecf84986af59f1f9f503bcebdc89c6d166/icons/moon.svg";
        hash = "sha256-IFuVnpQNWEHwzh0JyTMVPanZyUEwpU1cwMaMKvHUA9o=";
      };
      off = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/lucide-icons/lucide/59978cecf84986af59f1f9f503bcebdc89c6d166/icons/sun.svg";
        hash = "sha256-o5VciwQl/MXJuhLSvdd/5Tss1d0F53QqVvNC6Zb7Lvg=";
      };
      plus = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/lucide-icons/lucide/59978cecf84986af59f1f9f503bcebdc89c6d166/icons/eclipse.svg";
        hash = "sha256-qTVBxzdbJSjEG3Pelwcxr0banC69V+zJt9rUGtrnxfE=";
      };
    };
  };
}
