{
  pkgs,
  inputs,
  ...
}: {
  programs.git = {
    enable = true;
    signing.format = null;

    settings = {
      user = {
        name = "Rodey Seijkens";
        email = "me@rodey.nl";
      };
      init.defaultBranch = "main";
      credential.helper = "sops";
      push.autoSetupRemote = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = false;
    options = {
      line-numbers = true;
      side-by-side = true;
      navigate = true;
    };
  };

  programs.lazygit = {
    enable = true;
    settings = {
      git.pagers = [
        {
          colorArg = "always";
          pager = "delta --dark --paging=never";
        }
      ];
      gui = {
        mouseEvents = false;
        showCommandLog = false;
      };
    };
  };

  home.packages = [
    pkgs.gh
    pkgs.diffnav
    pkgs.pre-commit
    pkgs.gitleaks
    pkgs.gen-commit # generate commit messages using llm
    pkgs.git-lfs # Git Large File Storage
  ];

  programs.zsh.shellAliases = {
    # tools
    g = "lazygit && clear";
    gl = "lazygit log --screen-mode full && clear";
    gi = "onefetch --number-of-file-churns 0 --no-color-palette";

    # status/log
    gs = "git status";
    gd = "git diff | diffnav";
    gdu = "git diff | diffnav";
    gda = "git diff HEAD | diffnav";
    gds = "git diff --cached | diffnav";
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
    gcfu = "git commit --fixup HEAD";
    gcma = "git add --all && git commit -m";
    gcfua = "git add --all && git commit --fixup HEAD";
    ggcm = "gen-commit -c -a";
    ggcmw = "gen-commit -c -a -s";

    # history
    gb = "git branch";
    gsb = "git switch";
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
    gcl = "git clone";
  };
}
