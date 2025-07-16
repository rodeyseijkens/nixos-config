{pkgs, ...}: {
  programs.git = {
    enable = true;

    userName = "Rodey Seijkens";
    userEmail = "me@rodey.nl";

    extraConfig = {
      init.defaultBranch = "main";
      credential.helper = "store";
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
      push.autoSetupRemote = true;
    };

    delta = {
      enable = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        diff-so-fancy = true;
        navigate = true;
      };
    };
  };

  home.packages = [
    pkgs.gh
    pkgs.cz-cli # commitizen CLI tool
    # pkgs.git-lfs # Git Large File Storage
  ];

  programs.zsh.shellAliases = {
    g = "lazygit";
    gi = "onefetch --number-of-file-churns 0 --no-color-palette";
    ga = "git add";
    gaa = "git add --all";
    gs = "git status";
    gf = "git fetch";
    gfp = "git fetch --prune";
    gb = "git branch";
    gm = "git merge";
    gd = "git diff";
    gpl = "git pull";
    gplo = "git pull origin";
    gps = "git push";
    gpsf = "git push --force";
    gpso = "git push origin";
    gpst = "git push --follow-tags";
    gcl = "git clone";
    gc = "git commit";
    gcm = "git commit -m";
    gca = "git commit --amend";
    gcaa = "git add --all && git commit --amend --no-edit";
    gcz = "git cz";
    gcfu = "git commit --fixup HEAD";
    gcma = "git add --all && git commit -m";
    gcza = "git add --all && git cz";
    gcfua = "git add --all && git commit --fixup HEAD";
    gtag = "git tag -ma";
    gch = "git checkout";
    gchb = "git checkout -b";
    glog = "git log --oneline --decorate --graph";
    glol = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'";
    glola = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all";
    glols = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --stat";
  };
}
