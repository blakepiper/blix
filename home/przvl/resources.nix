{ pkgs }:

{
  wallpaper = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/mattbbia/lakes-and-light/1c14ea7b3fbb0bc8bd7097c74261e65affdc712b/backgrounds/lake-albano-1790-1792.jpg";
    hash = "sha256-iOBqjWHqqPaTNbFfKryBRF+P3A0MLSjqlYrH6sr5iqk=";
  };

  modelUsageSource = pkgs.fetchFromGitHub {
    owner = "blakepiper";
    repo = "blarchy";
    rev = "1badd3452d4e94f23b122970ae1f41bb79c68f85";
    hash = "sha256-nDTvfDm4PmZj8k4v8dsjy4Ru8LiEJa2nGLxas5CmBHo=";
  };

  icons = {
    aiUsage = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/lucide-icons/lucide/59978cecf84986af59f1f9f503bcebdc89c6d166/icons/sparkles.svg";
      hash = "sha256-9UmfM/CdcVgVHpvS7A+vef+PtXKS+E/dcobZbQ8EJNg=";
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
