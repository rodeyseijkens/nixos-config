{
  pkgs,
  lib,
  ...
}: {
  programs.dconf.enable = true;
  programs.zsh.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # pinentryFlavor = "";
  };
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc # libstdc++, libgcc_s — needed by Rust binaries (biome) and native npm addons
    openssl # TLS/SSL — needed by git HTTPS, curl, many npm tools
    zlib # compression — needed by git, many binaries
    curl # HTTP requests — needed by language servers, npm, mise
    libgit2 # git operations — needed by git-based tools
    icu # Unicode/ICU — needed by Node.js and many tools
    libssh2 # SSH — needed by git SSH operations
    krb5 # Kerberos — needed by git HTTP auth
    libuuid # UUID — needed by various tools
  ];
}
