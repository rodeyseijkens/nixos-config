{
  config,
  pkgs,
  lib,
  inputs,
  host,
  username,
  ...
}: let
  sharedSecretsFile = ../../secrets/secrets.yaml;
  hostSecretsFile = ../../secrets/hosts/${host}.yaml;
  hasSharedSecretsFile = builtins.pathExists sharedSecretsFile;
  hasHostSecretsFile = builtins.pathExists hostSecretsFile;
in {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # Configure sops-nix
  sops = {
    # Default sops file for secrets
    defaultSopsFile = sharedSecretsFile;
    # Use age for encryption (more modern than GPG)
    age = {
      # Automatically import host SSH keys as age keys
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      # Path where age keys are stored
      keyFile = "/var/lib/sops-nix/key.txt";
      # Generate the key file if it doesn't exist
      generateKey = true;
    };
    # Secrets will be available at /run/secrets/<name>

    # Shared secrets (materialized only when secrets/secrets.yaml exists)
    secrets = lib.mkMerge [
      (lib.mkIf hasSharedSecretsFile {
        git-credentials = {
          sopsFile = sharedSecretsFile;
          owner = username;
          mode = "0400";
        };
      })

      # Host-specific secret example (create secrets/hosts/<host>.yaml first)
      (lib.mkIf hasHostSecretsFile {
        # host-private-example = {
        #   sopsFile = hostSecretsFile;
        #   owner = username;
        #   mode = "0400";
        # };
      })
    ];
  };
}
