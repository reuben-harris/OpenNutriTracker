{
  description = "Pinned USDA food-level SQLite catalogue generator";

  # The parent supplies its pinned pkgs; this local flake has no Nix inputs.
  outputs = _: {
    flakeModules.default = import ./module.nix;
  };
}
