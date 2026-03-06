{
  description = "compass.nvim - fast workspace-aware project navigation for Neovim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    crate2nix = {
      url = "github:nix-community/crate2nix";
      flake = false;
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    crate2nix,
  }: let
    systems = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    eachSystem = f: nixpkgs.lib.genAttrs systems f;
  in {
    packages = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.callPackage ./nix/plugin.nix {inherit crate2nix;};
    });

    overlays.default = final: prev: {
      vimPlugins =
        (prev.vimPlugins or {})
        // {
          compass-nvim = self.packages.${final.system}.default;
        };
    };
  };
}
