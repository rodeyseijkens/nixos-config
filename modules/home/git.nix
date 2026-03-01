{
  pkgs,
  inputs,
  ...
}: {
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Rodey Seijkens";
        email = "me@rodey.nl";
      };
      init.defaultBranch = "main";
      credential.helper = "store";
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
      push.autoSetupRemote = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = false;
    options = {
      line-numbers = true;
      side-by-side = true;
      diff-so-fancy = true;
      navigate = true;
    };
  };

  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        mouseEvents = false;
      };
    };
  };

  home.packages = [
    pkgs.gh
    pkgs.github-copilot-cli # GitHub Copilot CLI
    pkgs.cz-cli # commitizen CLI tool
    pkgs.diffnav
    # pkgs.git-lfs # Git Large File Storage
  ];

  programs.zsh.shellAliases = {
    # tools
    g = "lazygit && clear";
    gl = "lazygit log --screen-mode full && clear";
    gi = "onefetch --number-of-file-churns 0 --no-color-palette";

    # status/log
    gs = "git status";
    gd = "git diff | diffnav";
    glog = "git log --oneline --decorate --graph";
    glol = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'";
    glola = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all";
    glols = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --stat";

    # stage/commit
    ga = "git add";
    gaa = "git add --all";
    gc = "git commit";
    gcm = "git commit -m";
    gca = "git commit --amend --no-edit";
    gcaa = "git add --all && git commit --amend --no-edit";
    gcz = "git cz";
    gcfu = "git commit --fixup HEAD";
    gcma = "git add --all && git commit -m";
    gcza = "git add --all && git cz";
    gcfua = "git add --all && git commit --fixup HEAD";
    ggcm = "${inputs.gen-commit.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/gen-commit -c -a";
    ggcmw = "${inputs.gen-commit.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/gen-commit -c -a -s";

    # history
    gb = "git branch";
    gch = "git checkout";
    gchb = "git checkout -b";
    grb = "git rebase";
    grs = "git reset --soft HEAD~";

    # sync
    gf = "git fetch";
    gfp = "git fetch --prune";
    gpl = "git pull";
    gplo = "git pull origin";
    gps = "git push";
    gpsf = "git push --force";
    gpso = "git push origin";
    gpst = "git push --follow-tags";
    gcl = "git clone";

    # misc
    gtag = "git tag -ma";
    gm = "git merge";
    gsp = "git stash push -m";
    gsl = "git stash list | sed -E 's/stash@\\{([0-9]+)\\}: (WIP on |On )?([^:]+): (.*)/\\x1b[44;37m \\1 \\x1b[0m\\x1b[34;48;5;238m\\xee\\x82\\xb0\\x1b[0m\\x1b[48;5;238;37m \\xee\\x82\\xa0 \\3 \\x1b[0m\\x1b[38;5;238m\\xee\\x82\\xb0\\x1b[0m \\4/'";
  };

  programs.zsh.initContent = ''
    # Function for git stash apply with parameter support
    gsa() { git stash apply "stash@{''${1:-0}}"; }
  '';
}
