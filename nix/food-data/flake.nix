{
  description = "Independent pinned food database catalogue generators";

  # The parent supplies its pinned pkgs; this local flake has no Nix inputs.
  outputs = _: {
    flakeModules.default = import ./module.nix;
    flakeModules.app-assets = import ./app-assets.nix;
  };
}
