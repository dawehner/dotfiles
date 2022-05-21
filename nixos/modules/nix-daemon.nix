{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib; {
  nix = {
    gc.automatic = true;
    gc.dates = "03:15";
    # should be enough?
    nrBuildUsers = lib.mkDefault 32;

    daemonIOSchedClass = "idle";
    daemonCPUSchedPolicy = "idle";

    settings = {
      # https://github.com/NixOS/nix/issues/719
      builders-use-substitutes = true;
      keep-outputs = true;
      keep-derivations = true;
      # in zfs we trust
      fsync-metadata = lib.boolToString (!config.boot.isContainer or config.fileSystems."/".fsType != "zfs");
      experimental-features = "nix-command flakes";
      substituters = [
        "https://nix-community.cachix.org"
        "https://mic92.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "mic92.cachix.org-1:gi8IhgiT3CYZnJsaW7fxznzTkMUOn1RY4GmXdT/nXYQ="
      ];
      trusted-users = ["joerg" "root"];
    };
  };

  imports = [./builder.nix];

  programs.command-not-found.enable = false;

  systemd.services.update-prefetch = {
    startAt = "hourly";
    script = ''
      export PATH=${lib.makeBinPath (with pkgs; [config.nix.package pkgs.jq pkgs.curl pkgs.iproute2])}
      # skip service if do not have a default route
      if ! ip r g 8.8.8.8; then
        exit
      fi
      drvpath=$(curl -L 'https://gitlab.com/Mic92/dotfiles/-/jobs/artifacts/master/raw/jobs.json?job=eval' | jq -r "select(.attr | contains(\"nixos-$(hostname)\")) | .drvPath")
      nix-store --add-root /run/next-system -r "$drvpath"
    '';
    # FIXME home-manager
    #if [[ -x /home/joerg/.nix-profile/bin/home-manager ]]; then
    #  nix run "github:Mic92/dotfiles/$last_build#hm-build" --  --out-link /run/next-home
    #fi
    serviceConfig = {
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

  # inputs == flake inputs in configurations.nix
  environment.etc = let
    inputsWithDate = lib.filterAttrs (_: input: input ? lastModified) inputs;
    flakeAttrs = input: (lib.mapAttrsToList (n: v: ''${n}="${v}"'')
      (lib.filterAttrs (n: v: (builtins.typeOf v) == "string") input));
    lastModified = name: input: ''
      flake_input_last_modified{input="${name}",${lib.concatStringsSep "," (flakeAttrs input)}} ${toString input.lastModified}'';
  in {
    "flake-inputs.prom" = {
      mode = "0555";
      text = ''
        # HELP flake_registry_last_modified Last modification date of flake input in unixtime
        # TYPE flake_input_last_modified gauge
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList lastModified inputsWithDate)}
      '';
    };
  };

  services.telegraf.extraConfig.inputs.file = [
    {
      data_format = "prometheus";
      files = ["/etc/flake-inputs.prom"];
    }
  ];

  nixpkgs.config.allowUnfree = true;
}
