{
  description = "Temporary built-in Kotlin compatibility for the health Flutter plugin";

  outputs = _: {
    lib.healthPatch = rec {
      supportedVersion = "13.3.2";
      patch = ./built-in-kotlin.patch;
      validateVersion =
        version:
        if version == supportedVersion then
          true
        else
          throw "health-compat supports health ${supportedVersion}, but pubspec.lock selects ${version}. Review the upstream Kotlin migration and remove or update the compatibility flake.";
    };
  };
}
