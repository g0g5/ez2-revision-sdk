"""Generate the PC FXC worklist and C++ combo headers for the CMake shader build."""

import argparse
from dataclasses import dataclass
from math import prod
from pathlib import Path
import re


# The legacy Perl scripts treated shader sources as bytes. Latin-1 retains any
# non-ASCII bytes in comments and default expressions when we copy them through.
SOURCE_ENCODING = "latin-1"
PROFILES = {
    "ps30": "ps_3_0",
    "ps20b": "ps_2_b",
    "ps20": "ps_2_0",
    "ps14": "ps_1_4",
    "ps11": "ps_1_1",
    "vs30": "vs_3_0",
    "vs20": "vs_2_0",
    "vs14": "vs_1_1",
    "vs11": "vs_1_1",
}
INCLUDE = re.compile(r'#include\s+"(.*)"', re.IGNORECASE)
COMBO = re.compile(r'^\s*//\s*(STATIC|DYNAMIC)\s*:\s*"(.*)"\s+"(\d+)\.\.(\d+)"')
SKIP = re.compile(r"^\s*//\s*SKIP\s*:\s*(.*)$")
CENTROID = re.compile(r"^\s*//\s*CENTROID\s*:\s*TEXCOORD(\d+)\s*$")
DEFAULT = re.compile(r"\[=([^\]]+)\]")
TAG = re.compile(r"\[[^\[\]]*\]")
PROFILE_TAG = {
    kind: re.compile(r"\[" + kind + r"\d+\w?\]", re.IGNORECASE)
    for kind in ("ps", "vs")
}


@dataclass(frozen=True)
class Combo:
    name: str
    low: str
    high: str

    @property
    def count(self) -> int:
        return int(self.high) - int(self.low) + 1


@dataclass
class ShaderCombos:
    static: list[Combo]
    dynamic: list[Combo]
    defaults: dict[str, str]
    skips: list[str]
    centroid_mask: int


def expand_name(name: str, model: str) -> list[str]:
    # These rules match LoadShaderListFile in Valve's valve_perl_helpers.pl.
    if model == "30":
        for alias, profile in (
            ("_ps2x", "_ps30"), ("_ps20b", "_ps30"), ("_ps20", "_ps30"),
            ("_vs20", "_vs30"), ("_vsxx", "_vs30"),
        ):
            name = re.sub(alias, profile, name, count=1, flags=re.IGNORECASE)
        return [name]
    for alias, profiles in (("_ps2x", ("_ps20", "_ps20b")), ("_vsxx", ("_vs11", "_vs20"))):
        if alias in name.lower():
            return [re.sub(alias, profile, name, count=1, flags=re.IGNORECASE) for profile in profiles]
    return [name]


def load_shader_list(shader_list: Path, model: str) -> list[tuple[str, str]]:
    selected = {}
    for number, line in enumerate(shader_list.read_text(encoding=SOURCE_ENCODING).splitlines(), 1):
        source = line.partition("//")[0].strip()
        if not source:
            continue
        if not re.fullmatch(r"\w+\.fxc", source, re.ASCII | re.IGNORECASE):
            raise ValueError(f"{shader_list}:{number}: expected an FXC shader filename, got {source}")
        if not (shader_list.parent / source).is_file():
            raise ValueError(f"{shader_list}:{number}: shader source is missing: {source}")
        for name in expand_name(Path(source).stem, model):
            key = name.lower()
            old_source, _ = selected.get(key, ("", ""))
            # Keep the first output position. A dedicated source wins over an
            # alias; otherwise the last entry wins.
            if old_source.lower() != key + ".fxc" or source.lower() == key + ".fxc":
                selected[key] = source, name
    if not selected:
        raise ValueError(f"{shader_list}: shader list is empty")
    return list(selected.values())


def shader_lines(directory: Path, source: str, stack: tuple[Path, ...] = ()):
    path = (directory / source).resolve()
    if path in stack:
        chain = " -> ".join(item.name for item in (*stack, path))
        raise ValueError(f"{path}: recursive shader include ({chain})")
    with path.open(encoding=SOURCE_ENCODING) as handle:
        for line in handle:
            line = line.removesuffix("\n")
            match = INCLUDE.search(line)
            if match:
                yield from shader_lines(directory, match[1], (*stack, path))
            else:
                yield line


def read_combos(directory: Path, source: str, model: str) -> ShaderCombos:
    static = []
    dynamic = []
    defaults = {}
    skips = []
    centroids = set()
    profile_tag = PROFILE_TAG[model[:2]]
    for line in shader_lines(directory, source):
        if "[XBOX]" in line:
            continue
        if profile_tag.search(line) and f"[{model}]" not in line.lower():
            continue
        default = DEFAULT.search(line)
        # fxc_prep.pl removes the first bracketed annotation per line.
        line = TAG.sub("", line, count=1)
        declaration = COMBO.match(line)
        if declaration:
            kind, name, low, high = declaration.groups()
            combo = Combo(name, low, high)
            if kind == "STATIC":
                static.append(combo)
                defaults[name] = default[1] if default else ""
            else:
                dynamic.append(combo)
        skip = SKIP.match(line)
        if skip:
            skips.append(skip[1])
        centroid = CENTROID.match(line)
        if centroid:
            centroids.add(int(centroid[1]))
    return ShaderCombos(static, dynamic, defaults, skips, sum(1 << index for index in centroids))


def count_combos(combos: list[Combo]) -> int:
    return prod(combo.count for combo in combos)


def worklist_block(source: str, name: str, profile: str, combos: ShaderCombos) -> str:
    dynamic_count = count_combos(combos.dynamic)
    total_count = dynamic_count * count_combos(combos.static)
    skip_expression = "".join(f"({skip})||" for skip in combos.skips) + "0"
    return "\n".join([
        "**** generated by ShaderPrep.py ****",
        f"#BEGIN {name}",
        source,
        "#DEFINES-D:",
        *(f"{combo.name}={combo.low}..{combo.high}" for combo in combos.dynamic),
        "#DEFINES-S:",
        *(f"{combo.name}={combo.low}..{combo.high}" for combo in combos.static),
        "#SKIP:",
        skip_expression,
        "#COMMAND:",
        f"fxc.exe /DTOTALSHADERCOMBOS={total_count} /DCENTROIDMASK={combos.centroid_mask} "
        f"/DNUMDYNAMICCOMBOS={dynamic_count} /DFLAGS=0x0 ",
        f"/Dmain=main /Emain /T{profile} /DSHADER_MODEL_{profile.upper()}=1 "
        f"/nologo /Foshader.o {source}>output.txt 2>&1",
        "#END",
        "**** end ****",
        "",
    ])


def combo_members(combo: Combo) -> str:
    name = combo.name
    return f"""private:
	int m_n{name};
#ifdef _DEBUG
	bool m_b{name};
#endif
public:
	void Set{name}( int i )
	{{
		Assert( i >= {combo.low} && i <= {combo.high} );
		m_n{name} = i;
#ifdef _DEBUG
		m_b{name} = true;
#endif
	}}
	void Set{name}( bool i )
	{{
		m_n{name} = i ? 1 : 0;
#ifdef _DEBUG
		m_b{name} = true;
#endif
	}}
"""


def index_class(
    name: str, kind: str, prefix: str, combos: list[Combo], defaults: dict[str, str], scale: int
) -> str:
    class_name = f"{name}_{kind}_Index"
    arguments = "( )" if kind == "Static" else "()"
    lines = [f"class {class_name}\n{{\n"]
    lines.extend(combo_members(combo) for combo in combos)
    lines.append(f"public:\n\t{class_name}{arguments}\n\t{{\n")
    for combo in combos:
        value = defaults.get(combo.name)
        assigned = "true" if value else "false"
        lines.append(
            f"#ifdef _DEBUG\n\t\tm_b{combo.name} = {assigned};\n#endif // _DEBUG\n"
            f"\t\tm_n{combo.name} = {value or '0'};\n"
        )
    lines.append(
        "\t}\n\tint GetIndex()\n\t{\n"
        "\t\t// Asserts to make sure that we aren't using any skipped combinations.\n"
        "\t\t// Asserts to make sure that we are setting all of the combination vars.\n"
        "#ifdef _DEBUG\n"
    )
    if combos:
        flags = " && ".join(f"m_b{combo.name}" for combo in combos)
        lines.append(f"\t\tbool bAll{kind}VarsDefined = {flags};\n\t\tAssert( bAll{kind}VarsDefined );\n")
    lines.append("#endif // _DEBUG\n\t\treturn ")
    for combo in combos:
        lines.append(f"( {scale} * m_n{combo.name} ) + ")
        scale *= combo.count
    lines.append(f"0;\n\t}}\n}};\n#define shader{kind}Test_{name} ")
    lines.extend(
        f"{prefix}_forgot_to_set_{kind.lower()}_{combo.name} + "
        for combo in combos if not defaults.get(combo.name)
    )
    lines.append("0\n")
    return "".join(lines)


def combo_header(name: str, profile: str, combos: ShaderCombos) -> str:
    name = name.lower()
    prefix = "vsh" if profile.startswith("vs") else "psh"
    return (
        '#include "shaderlib/cshader.h"\n'
        + index_class(name, "Static", prefix, combos.static, combos.defaults, count_combos(combos.dynamic))
        + index_class(name, "Dynamic", prefix, combos.dynamic, {}, 1)
    )


def prepare(directory: Path, entries: list[tuple[str, str]]) -> None:
    headers = directory / "fxctmp9"
    headers.mkdir(exist_ok=True)
    with (directory / "filelist.txt").open("w", encoding=SOURCE_ENCODING, newline="\r\n") as worklist:
        for source, name in entries:
            model = name.rsplit("_", 1)[-1].lower()
            if model not in PROFILES:
                raise ValueError(f"{source}: unsupported output shader model: {name}")
            profile = PROFILES[model]
            combos = read_combos(directory, source, model)
            (headers / f"{name}.inc").write_text(
                combo_header(name, profile, combos), encoding=SOURCE_ENCODING, newline="\r\n"
            )
            worklist.write(worklist_block(source, name, profile, combos))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("list", "prepare"))
    parser.add_argument("shader_list", type=Path)
    parser.add_argument("model", choices=("20b", "30"))
    args = parser.parse_args()
    try:
        shader_list = args.shader_list.resolve()
        entries = load_shader_list(shader_list, args.model)
        if args.mode == "list":
            for source, name in entries:
                print(f"{source}-----{name}")
        else:
            prepare(shader_list.parent, entries)
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
