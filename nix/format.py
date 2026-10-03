import pathlib
import subprocess


def git_files(*args):
    return subprocess.check_output(["git", *args, "-z"]).decode().split("\0")


root = pathlib.Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"]).decode().strip())
paths = set(git_files("diff", "--name-only", "HEAD"))
paths.update(git_files("ls-files", "--others", "--exclude-standard"))
for suffix, command in [(".dart", ["dart", "format"]), (".nix", ["nixfmt"])]:
    files = sorted(
        str(root / path)
        for path in paths
        if path.endswith(suffix)
        and (root / path).is_file()
        and not path.startswith("lib/generated/")
        and not path.endswith(".g.dart")
    )
    if files:
        subprocess.run([*command, *files], check=True)
    else:
        print(f"No changed authored {suffix} files to format.")
