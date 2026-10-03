# OpenNutriTracker

An open-source Android app for calorie, nutrition, and activity tracking.

## Development

Development is supported on **x86_64 Linux**. Install Nix with flakes enabled;
the flake provides Flutter, Dart, Java, Gradle, and the Android SDK. Tool versions
and dependency hashes are pinned in the repository's lockfiles.

| Command | What it does |
| --- | --- |
| `nix develop` | Makes the pinned tools available to your terminal and editor. Use for editor integration or direct Flutter/ADB troubleshooting. |
| `nix run .#emulator` | Creates the project Android emulator if missing, then starts it with KVM acceleration. |
| `nix run .#run` | Prepares locked dependencies, regenerates Dart code, and launches the develop app on a running emulator or connected phone with hot reload. |
| `nix run .#format` | Formats changed/new authored Dart files with Dart's formatter and changed/new Nix files with nixfmt, compared with `HEAD`. |
| `nix flake check` | Checks English localization, static analysis, existing unit/widget tests, and Nix formatting in isolated builds. |
| `nix build .#apk` | Builds the develop debug APK in the Nix sandbox; the APK is available under `result/`. |
| `nix run .#update-gradle-deps` | Refreshes the hashed Android dependency manifest after Flutter, plugin, or native dependency changes, keeping selected versions. |
| `nix flake update` | Deliberately updates pinned Nix inputs. Refresh Android dependencies afterward if the selected toolchain changes. |

Start the emulator in one terminal, then run the app in another. A connected
Android phone can be used instead. Flutter asks you to choose if multiple
supported devices are connected. In the running Flutter session, press `r` for
hot reload, `R` for hot restart, or `q` to end the session.

The emulator requires hardware virtualization and access to `/dev/kvm`. The host
must grant your user access, commonly through its `kvm` group. USB development
requires Android USB debugging, authorization on the phone, and the host's Android
udev rules (on NixOS, `programs.adb.enable = true`). Host permissions are configured
outside this flake.

## License

[GPL-3.0](LICENSE). Bundled fonts retain their [font license](fonts/OFL.txt), and
bundled demo photos retain their in-app Unsplash attribution.
