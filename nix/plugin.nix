{
  pkgs,
  lib,
  crate2nix,
  stdenv ? pkgs.stdenv,
  ...
}: let
  tools = pkgs.callPackage "${crate2nix}/tools.nix" {};

  cargoNix = tools.appliedCargoNix {
    name = "compass_core";
    src = ../.;
  };

  isDarwin = stdenv.hostPlatform.isDarwin;

  crateOverrides = pkgs.defaultCrateOverrides // {
    compass_core = attrs: {
      # macOS needs dynamic_lookup for nvim-oxi symbols resolved at runtime
      NIX_LDFLAGS = lib.optionalString isDarwin "-undefined dynamic_lookup";
    };
  };

  rustLib = cargoNix.rootCrate.build.override {
    inherit crateOverrides;
  };

  # Platform-specific shared library extension
  soName =
    if isDarwin
    then "libcompass_core.dylib"
    else "libcompass_core.so";
in
  pkgs.runCommand "compass-nvim" {
    meta = {
      description = "Fast workspace-aware project navigation for Neovim";
      license = lib.licenses.mit;
    };
  } ''
    mkdir -p $out/lua $out/plugin

    # Copy the native module — Lua always expects .so extension
    cp ${rustLib.lib}/lib/${soName} $out/lua/compass_core.so

    # Copy Lua plugin files
    cp -r ${../lua/compass} $out/lua/compass
    cp ${../plugin/compass.lua} $out/plugin/compass.lua
  ''
