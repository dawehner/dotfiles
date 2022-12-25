{self, inputs, ...}: {
  perSystem = {pkgs, ...}: {
    apps.hm = {
      type = "app";
      program = "${pkgs.writeScriptBin "hm" ''
        export PATH=${pkgs.lib.makeBinPath [pkgs.git pkgs.coreutils pkgs.nix pkgs.jq]}
        declare -A profiles=(["turingmachine"]="desktop" ["eddie"]="desktop" ["eve"]="eve" ["bernie"]="bernie" ["grandalf"]="common-aarch64" ["yasmin"]="common-aarch64")
        profile=common
        if [[ -n ''${profiles[$HOSTNAME]:-} ]]; then
          profile=''${profiles[$HOSTNAME]}
        fi
        usage() {
          echo "hm (profile|build|switch)"
          exit 0
        }
        main() {
          cmd=$1
          shift
          case "$cmd" in
          -h|--help)
            usage
            ;;
          profile)
            echo "$profile"
            ;;
          build)
            nix build --no-link --show-trace --json "${toString ./..}#hmConfigurations.''${profile}.activationPackage" "$@" | jq -r '.[] | .outputs | .out'
            ;;
          switch)
            oldpath=$(realpath /nix/var/nix/profiles/per-user/$USER/home-manager)
            path=$(main build "$@")
            if [[ -e $oldpath ]]; then
              nix store diff-closures "$oldpath" "$path"
            fi
            $path/activate
            ;;
          esac
        }
        if [[ "$#" -lt 1 ]]; then
          usage
        fi
        main "$@"
      ''}/bin/hm";
    };
  };

  flake = let
    hmConfiguration = {
      extraModules ? [],
      system ? "x86_64-linux",
    }: (inputs.home-manager.lib.homeManagerConfiguration {
      modules = [
        {
          _module.args.self = self;
          _module.args.inputs = self.inputs;
          imports =
            extraModules
            ++ [
              ./common.nix
              inputs.nur.hmModules.nur
            ];
          home.username = "joerg";
          home.homeDirectory = "/home/joerg";
        }
      ];
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    });
  in {
    hmConfigurations = {
      common = hmConfiguration {};
      common-aarch64 = hmConfiguration {
        system = "aarch64-linux";
      };

      desktop = hmConfiguration {
        extraModules = [
          ./desktop.nix
          inputs.nix-index-database.hmModules.nix-index
          inputs.hyprland.homeManagerModules.default
          ({pkgs, ...}: {
            programs.waybar.package = inputs.hyprland.packages.${pkgs.system}.waybar-hyprland;
            home.packages = [
              inputs.hyprland-contrib.packages.${pkgs.system}.grimblast
            ];
          })
        ];
      };
      eve = hmConfiguration {
        extraModules = [./eve.nix];
      };
      bernie = hmConfiguration {
        extraModules = [./bernie.nix];
      };
    };
  };
}
