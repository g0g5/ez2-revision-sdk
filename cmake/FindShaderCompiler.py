"""Locate the Windows shader compiler from Source SDK Base 2013 Singleplayer."""

import argparse
from pathlib import Path
import re
import sys
import winreg


APP_ID = "243730"
COMPILER_NAME = "shadercompile.exe"
LOCAL_KEY = "REVISION_SHADER_SDK_BIN"
UNINSTALL_KEY = (
    r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App " + APP_ID
)
VDF_TOKEN = re.compile(r'\s+|//[^\r\n]*|[{}]|"(?:\\.|[^"\\])*"|[^"{}\s]+')


def registry_path(hive: int, key: str, name: str, view: int = 0) -> Path | None:
    try:
        with winreg.OpenKey(hive, key, access=winreg.KEY_READ | view) as entry:
            value, kind = winreg.QueryValueEx(entry, name)
    except OSError:
        return None
    if kind == winreg.REG_EXPAND_SZ:
        value = winreg.ExpandEnvironmentStrings(value)
    if isinstance(value, str) and value and Path(value).is_absolute():
        return Path(value)
    return None


def read_local_bin(path: Path) -> Path | None:
    try:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
    except FileNotFoundError:
        return None

    bin_dir = None
    for number, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        value = value.strip()
        if value.startswith(("'", '"')) and len(value) >= 2 and value[-1] == value[0]:
            value = value[1:-1]
        if not separator or key.strip() != LOCAL_KEY or bin_dir is not None or not value:
            raise ValueError(f"{path}:{number}: expected a single {LOCAL_KEY}=<absolute bin directory>")
        bin_dir = Path(value)
        if not bin_dir.is_absolute():
            raise ValueError(f"{path}:{number}: {LOCAL_KEY} must be an absolute bin directory")
    return bin_dir


def vdf_tokens(path: Path):
    data = path.read_text(encoding="utf-8-sig")
    position = 0
    while position < len(data):
        match = VDF_TOKEN.match(data, position)
        if not match:
            raise ValueError(f"{path}: malformed KeyValues token at character {position + 1}")
        token = match[0]
        position = match.end()
        if not token.isspace() and not token.startswith("//"):
            yield token


def read_vdf(path: Path) -> dict:
    tokens = iter(vdf_tokens(path))

    def unquote(token: str) -> str:
        if token.startswith('"'):
            return re.sub(r'\\([\\"])', r"\1", token[1:-1])
        return token

    def read_section(nested: bool) -> dict:
        section = {}
        for key in tokens:
            if key == "}" and nested:
                return section
            value = next(tokens, None)
            if key in ("{", "}") or value in (None, "}"):
                raise ValueError(f"{path}: expected a KeyValues key and value")
            section[unquote(key).casefold()] = read_section(True) if value == "{" else unquote(value)
        if nested:
            raise ValueError(f"{path}: unclosed KeyValues section")
        return section

    return read_section(False)


def steam_libraries(steam_root: Path, diagnostics: list[str]):
    yield steam_root
    library_file = steam_root / "steamapps" / "libraryfolders.vdf"
    try:
        folders = read_vdf(library_file).get("libraryfolders", {})
        if not isinstance(folders, dict):
            raise ValueError(f"{library_file}: expected a libraryfolders section")
    except (OSError, ValueError) as error:
        diagnostics.append(str(error))
        return
    for index, entry in folders.items():
        if not index.isdecimal():
            continue
        # New files use an object with a path field. Older files store the path directly.
        folder = entry.get("path") if isinstance(entry, dict) else entry
        if isinstance(folder, str) and Path(folder).is_absolute():
            yield Path(folder)


def steam_candidates(diagnostics: list[str]):
    for view in (winreg.KEY_WOW64_64KEY, winreg.KEY_WOW64_32KEY):
        install = registry_path(winreg.HKEY_LOCAL_MACHINE, UNINSTALL_KEY, "InstallLocation", view)
        if install is not None:
            yield install / "bin" / COMPILER_NAME, f"Steam uninstall registry, App {APP_ID}"

    steam_root = registry_path(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam", "SteamPath")
    if steam_root is None:
        diagnostics.append(r"SteamPath is missing under HKCU\Software\Valve\Steam")
        return
    for library in dict.fromkeys(steam_libraries(steam_root, diagnostics)):
        manifest = library / "steamapps" / f"appmanifest_{APP_ID}.acf"
        try:
            app = read_vdf(manifest).get("appstate")
        except FileNotFoundError:
            continue
        except (OSError, ValueError) as error:
            diagnostics.append(str(error))
            continue
        if isinstance(app, dict) and app.get("appid") == APP_ID:
            name = app.get("installdir")
            if isinstance(name, str) and name not in ("", ".", "..") and Path(name).name == name:
                yield library / "steamapps" / "common" / name / "bin" / COMPILER_NAME, str(manifest)
                continue
        diagnostics.append(f"{manifest}: expected App ID {APP_ID} and a valid installdir")


def check_runtime(compiler: Path, required_dlls: list[str]) -> None:
    if not compiler.is_absolute():
        raise ValueError(f"expected an absolute path, got {compiler}")
    for path in (compiler, *(compiler.parent / dll for dll in required_dlls)):
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"missing or empty shader compiler file: {path}")


def locate_compiler(
    manual: str, local_config: Path, required_dlls: list[str]
) -> tuple[Path, str]:
    if manual:
        compiler = Path(manual)
        source = "REVISION_SHADERCOMPILE_EXECUTABLE"
    else:
        local_bin = read_local_bin(local_config)
        if local_bin is None:
            diagnostics = []
            checked = set()
            for compiler, source in steam_candidates(diagnostics):
                if compiler in checked:
                    continue
                checked.add(compiler)
                try:
                    check_runtime(compiler, required_dlls)
                except (OSError, ValueError) as error:
                    diagnostics.append(f"{source}: {error}")
                    continue
                return compiler, source
            details = "\n".join(diagnostics)
            raise ValueError(
                f"Could not find Source SDK Base 2013 Singleplayer (Steam App {APP_ID}).\n"
                f"Install it through Steam, set {LOCAL_KEY} in {local_config}, "
                "or pass -DREVISION_SHADERCOMPILE_EXECUTABLE=<absolute exe path>."
                + (f"\n{details}" if details else "")
            )
        compiler = local_bin / COMPILER_NAME
        source = str(local_config)
    try:
        check_runtime(compiler, required_dlls)
    except (OSError, ValueError) as error:
        raise ValueError(f"{source}: {error}") from error
    return compiler, source


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--compiler", default="")
    parser.add_argument("--required-dlls", nargs="+", required=True)
    args = parser.parse_args()

    # CMake decodes both captured streams as UTF-8.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    try:
        compiler, source = locate_compiler(args.compiler, args.config, args.required_dlls)
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")
    print(compiler.as_posix())
    print(source, file=sys.stderr)


if __name__ == "__main__":
    main()
