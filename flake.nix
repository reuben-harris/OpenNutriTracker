{
  description = "OpenNutriTracker Android development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    gradle2nix.url = "github:tadfisher/gradle2nix/v2";
    gradle2nix.inputs.nixpkgs.follows = "nixpkgs";
    health-compat.url = "path:./nix/health-compat";
    food-data.url = "path:./nix/food-data";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        ./nix/toolchain.nix
        ./nix/dependencies.nix
        ./nix/android.nix
        ./nix/devshell.nix
        ./nix/commands.nix
        ./nix/checks.nix
        inputs.food-data.flakeModules.default
        inputs.food-data.flakeModules.app-assets
      ];
    };
}
