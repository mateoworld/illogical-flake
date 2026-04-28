{
  description = "Illogical Impulse - Home-manager module for end-4's Hyprland dotfiles with QuickShell";

  inputs = {
    # These will be overridden by the user's flake
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Default dotfiles - can be overridden by users
    dotfiles = {
      url = "git+https://github.com/end-4/dots-hyprland?submodules=1";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, quickshell, nur, dotfiles, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Workaround: nixpkgs-unstable hyprland-plugins broken due to missing HookSystemManager.hpp
      # Fix from: https://github.com/JonnieCache/nixpkgs/commit/231ea250
      # Tracking: NixOS/nixpkgs#502324
      hyprlandPluginsFix = final: prev: {
        hyprlandPlugins = let
          patchedPkgs = import (builtins.fetchTree {
            type = "github";
            owner = "JonnieCache";
            repo = "nixpkgs";
            rev = "231ea250eee538df1b939ca7899e0e80e7bcb08c";
          }) {
            inherit (prev) system;
            config.allowUnfree = true;
          };

          fixedHyprgrass = patchedPkgs.hyprlandPlugins.hyprgrass.overrideAttrs (old: {
            version = "0.8.2-unstable-2025-04-14";
            src = final.fetchFromGitHub {
              owner = "horriblename";
              repo = "hyprgrass";
              rev = "cd4810130e2e8fd8a0f7be4b69b42b9c902ad00a";
              hash = "sha256-PJ9w8WTTxI/lJVgCFsNRYodG4Ab3H4EOgjSq1dHli+A=";
            };
          });
        in patchedPkgs.hyprlandPlugins // {
          hyprgrass = fixedHyprgrass;
        };
      };

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      pkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ hyprlandPluginsFix ];
        config.allowUnfree = true;
      });

      flakeInputs = { inherit quickshell nur dotfiles; };
    in {
      overlays.default = hyprlandPluginsFix;

      # Home-manager module for user configuration
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          system = pkgs.system or "x86_64-linux";
        in (import ./home-module.nix) {
          inherit config lib;
          pkgs = pkgsFor.${system};
          inputs = flakeInputs;
        };
      homeManagerModules.illogical-flake = self.homeManagerModules.default;
    };
}
