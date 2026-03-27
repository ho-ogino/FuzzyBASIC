#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
SRC_DIR = ROOT_DIR / "src"
OUT_DIR = ROOT_DIR / "out"
DIST_DIR = ROOT_DIR / "dist"
ASSETS_DIR = ROOT_DIR / "assets"
DISK_DIR = ROOT_DIR / "disk"
TOOLS_DIR = ROOT_DIR / "tools"
DISK_CLEAN_DIR = DISK_DIR / "clean"
DISK_WORK_DIR = DISK_DIR / "work"
HUDISK_EXE = ROOT_DIR / "tools" / "HuDisk.exe"


@dataclass(frozen=True)
class ExtraBuild:
    source: str
    args: tuple[str, ...]
    outputs: tuple[tuple[str, str], ...]
    assembler: str = ""  # Override assembler (empty = use default)


@dataclass(frozen=True)
class Target:
    name: str
    source: str
    args: tuple[str, ...]
    outputs: tuple[tuple[str, str], ...]
    description: str
    version: str = ""
    extra_builds: tuple[ExtraBuild, ...] = ()


TARGETS = {
    "lsx": Target(
        name="lsx",
        version="1.2L",
        source="FUZZY.ASM",
        args=("-dl", "IS_LSX=1", "-gap", "0", "-bin", "-lst", "-sym", "-f"),
        outputs=(
            ("FUZZY.BIN", "FZBASIC.COM"),
            ("FUZZY.LST", "FUZZY.LST"),
            ("FUZZY.SYM", "FUZZY.SYM"),
        ),
        description="Build the LSX-Dodgers binary.",
        extra_builds=(
            # $C300版 (MAGIC非同居、メモリ末尾配置)
            ExtraBuild(
                source="playerAkm_x1_wrapper.asm",
                args=("-o", "PSGDRV_AKM", "-s"),
                outputs=(("PSGDRV_AKM.bin", "PSGAKM.BIN"), ("PSGDRV_AKM.sym", "PSGAKM.SYM")),
                assembler="/usr/local/bin/rasm",
            ),
            ExtraBuild(
                source="playerAkg_x1_wrapper.asm",
                args=("-o", "PSGDRV_AKG", "-s"),
                outputs=(("PSGDRV_AKG.bin", "PSGAKG.BIN"), ("PSGDRV_AKG.sym", "PSGAKG.SYM")),
                assembler="/usr/local/bin/rasm",
            ),
        ),
    ),
    "sos": Target(
        name="sos",
        source="FUZZYSOS.ASM",
        args=("-gap", "0", "-bin", "-lst", "-sym", "-f"),
        outputs=(
            ("FUZZYSOS.BIN", "FZBASIC"),
            ("FUZZYSOS.LST", "FUZZYSOS.LST"),
            ("FUZZYSOS.SYM", "FUZZYSOS.SYM"),
        ),
        description="Build the S-OS binary.",
    ),
}

DEFAULT_BUILD_TARGETS = ("lsx",)
DEFAULT_DEPLOY_TARGETS = ("lsx",)
VALID_TARGET_NAMES = tuple(sorted([*TARGETS.keys(), "all"]))

DEPLOY_TARGETS = {
    "lsx": {
        "clean_image": "LSX162c.d88",
        "work_image": "FuzzyBASIC-LSX.d88",
        "zip_name": "FuzzyBASIC_v1.2L.zip",
        "d88_name": "FuzzyBASIC_v1.2L.d88",
        "items": (
            {"path": OUT_DIR / "lsx" / "FZBASIC.COM", "image_name": "FZBASIC.COM"},
            {"path": ASSETS_DIR / "MAGIC.BIN", "image_name": "MAGIC.BIN"},
            {"path": ASSETS_DIR / "PCG.BIN", "image_name": "PCG.BIN"},
            {"path": ASSETS_DIR / "FURUI.BAS", "image_name": "FURUI.BAS"},
            {"path": ASSETS_DIR / "CKYOK.BAS", "image_name": "CKYOK.BAS"},
            {"path": ASSETS_DIR / "PCG_LSX.BAS", "image_name": "PCG.BAS"},
            {"path": OUT_DIR / "lsx" / "PSGAKM.BIN", "image_name": "PSGAKM.BIN"},
            {"path": OUT_DIR / "lsx" / "PSGAKG.BIN", "image_name": "PSGAKG.BIN"},
            {"path": ASSETS_DIR / "BGM.BAS", "image_name": "BGM.BAS"},
            {"path": ASSETS_DIR / "BGM.AKG", "image_name": "BGM.AKG"},
            {"path": ASSETS_DIR / "BGM.AKM", "image_name": "BGM.AKM"},
            {"path": ASSETS_DIR / "SE.AKX", "image_name": "SE.AKX"},
        ),
        "dist_files": (
            DISK_DIR / "README.txt",
            DISK_DIR / "COPYING",
            DISK_DIR / "COPYING.AT3",
        ),
    },
    "sos": {
        "clean_image": "S-OS.d88",
        "work_image": "FuzzyBASIC-S-OS.d88",
        "zip_name": "FuzzyBASIC_v1.1S.zip",
        "d88_name": "FuzzyBASIC_v1.1S.d88",
        "items": (
            {
                "path": OUT_DIR / "sos" / "FZBASIC",
                "image_name": "FZBASIC",
                "load_address": "3000",
                "exec_address": "3000",
            },
            {"path": ASSETS_DIR / "MAGIC.BIN", "image_name": "MAGIC.BIN"},
            {"path": ASSETS_DIR / "PCG.BIN", "image_name": "PCG.BIN"},
            {"path": ASSETS_DIR / "FURUI.BAS", "image_name": "FURUI.BAS"},
            {"path": ASSETS_DIR / "CKYOK.BAS", "image_name": "CKYOK.BAS"},
            {"path": ASSETS_DIR / "PCG_S-OS.BAS", "image_name": "PCG.BAS"},
        ),
        "dist_files": (
            DISK_DIR / "README.txt",
            DISK_DIR / "COPYING",
        ),
    },
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[1:]
    if argv and argv[0] not in ("build", "deploy") and not argv[0].startswith("-"):
        argv = ["build", *argv]

    parser = argparse.ArgumentParser(
        description="Build or deploy FuzzyBASIC targets."
    )
    parser.add_argument(
        "command",
        nargs="?",
        choices=("build", "deploy"),
        default="build",
        help="Choose build or deploy. Defaults to build.",
    )
    parser.add_argument(
        "targets",
        nargs="*",
        default=None,
        metavar="target",
        help="Targets to build or deploy.",
    )
    parser.add_argument(
        "--assembler",
        help="Path to ailz80asm. Falls back to $AILZ80ASM, AILZ80ASM, or ailz80asm.",
    )
    parser.add_argument(
        "--keep-work",
        action="store_true",
        help="Keep the copied working directory under out/<target>/work.",
    )
    parser.add_argument(
        "--autorun",
        action="store_true",
        help="Enable AUTORUN.BAS on startup (adds ENABLE_AUTORUN=1 define).",
    )
    parser.add_argument(
        "--ndc",
        help="Path to ndc. Falls back to $NDC, ndc, or NDC.EXE on PATH.",
    )
    parser.add_argument(
        "--hudisk",
        help="Path to HuDisk.exe. Falls back to tools/HuDisk.exe or ../HuDisk.exe.",
    )
    args = parser.parse_args(argv)
    if args.targets is None:
        args.targets = []
    invalid_targets = [target for target in args.targets if target not in VALID_TARGET_NAMES]
    if invalid_targets:
        parser.error(
            "invalid target(s): "
            + ", ".join(invalid_targets)
            + " (choose from "
            + ", ".join(VALID_TARGET_NAMES)
            + ")"
        )
    return args


def resolve_assembler(cli_value: str | None) -> str:
    candidates: list[str] = []
    if cli_value:
        candidates.append(cli_value)
    env_value = os.environ.get("AILZ80ASM")
    if env_value:
        candidates.append(env_value)
    candidates.extend(["AILZ80ASM", "ailz80asm"])

    for candidate in candidates:
        expanded = Path(candidate).expanduser()
        if expanded.exists():
            return str(expanded.resolve())
        found = shutil.which(candidate)
        if found:
            return found

    raise SystemExit(
        "ailz80asm was not found. Set $AILZ80ASM or pass --assembler /path/to/ailz80asm."
    )


def resolve_ndc(cli_value: str | None) -> str:
    candidates: list[str] = []
    if cli_value:
        candidates.append(cli_value)
    env_value = os.environ.get("NDC")
    if env_value:
        candidates.append(env_value)
    candidates.extend(["ndc", "NDC.EXE"])

    for candidate in candidates:
        expanded = Path(candidate).expanduser()
        if expanded.exists():
            return str(expanded.resolve())
        found = shutil.which(candidate)
        if found:
            return found

    raise SystemExit("ndc was not found. Set $NDC or pass --ndc /path/to/ndc.")


def resolve_hudisk(cli_value: str | None) -> str:
    candidates: list[Path | str] = []
    if cli_value:
        candidates.append(cli_value)
    env_value = os.environ.get("HUDISK")
    if env_value:
        candidates.append(env_value)
    candidates.extend(
        [
            HUDISK_EXE,
            ROOT_DIR.parent / "HuDisk.exe",
            "HuDisk.exe",
        ]
    )

    for candidate in candidates:
        if isinstance(candidate, Path):
            expanded = candidate.expanduser()
            if expanded.exists():
                return str(expanded.resolve())
            continue

        expanded = Path(candidate).expanduser()
        if expanded.exists():
            return str(expanded.resolve())
        found = shutil.which(candidate)
        if found:
            return found

    raise SystemExit(
        "HuDisk.exe was not found. Place it in tools/, set $HUDISK, or pass --hudisk /path/to/HuDisk.exe."
    )


def expand_targets(selected: list[str], default_names: tuple[str, ...]) -> list[Target]:
    if not selected:
        return [TARGETS[name] for name in default_names]
    if selected == ["all"]:
        return [TARGETS[name] for name in ("lsx", "sos")]

    ordered: list[Target] = []
    seen: set[str] = set()
    for name in selected:
        if name == "all":
            return [TARGETS[target_name] for target_name in ("lsx", "sos")]
        if name not in seen:
            ordered.append(TARGETS[name])
            seen.add(name)
    return ordered


def prepare_work_dir(target_dir: Path) -> Path:
    work_dir = target_dir / "work"
    if work_dir.exists():
        shutil.rmtree(work_dir)
    work_dir.mkdir(parents=True)

    for source_path in SRC_DIR.iterdir():
        if source_path.is_file():
            shutil.copy2(source_path, work_dir / source_path.name)

    return work_dir


def build_target(target: Target, assembler: str, keep_work: bool,
                  extra_defines: list[str] | None = None) -> None:
    target_dir = OUT_DIR / target.name
    if target_dir.exists():
        shutil.rmtree(target_dir)
    target_dir.mkdir(parents=True)

    work_dir = prepare_work_dir(target_dir)
    # Inject extra defines after existing -dl arguments (ailz80asm)
    args_list = list(target.args)
    if extra_defines:
        try:
            dl_idx = args_list.index("-dl")
            insert_at = dl_idx + 1
            while insert_at < len(args_list) and not args_list[insert_at].startswith("-"):
                insert_at += 1
            for d in reversed(extra_defines):
                args_list.insert(insert_at, d)
        except ValueError:
            args_list.extend(["-dl", *all_extra])
    command = [assembler, target.source, *args_list]

    print(f"[build] {target.name}: {' '.join(command)}")
    subprocess.run(command, cwd=work_dir, check=True)

    for produced_name, output_name in target.outputs:
        produced_path = work_dir / produced_name
        if not produced_path.exists():
            raise FileNotFoundError(
                f"Expected output was not generated for {target.name}: {produced_name}"
            )
        shutil.copy2(produced_path, target_dir / output_name)

    for extra in target.extra_builds:
        extra_asm = extra.assembler or assembler
        extra_command = [extra_asm, extra.source, *extra.args]
        print(f"[build] {target.name} (extra): {' '.join(extra_command)}")
        subprocess.run(extra_command, cwd=work_dir, check=True)
        for produced_name, output_name in extra.outputs:
            produced_path = work_dir / produced_name
            if not produced_path.exists():
                raise FileNotFoundError(
                    f"Expected output was not generated for {target.name}: {produced_name}"
                )
            shutil.copy2(produced_path, target_dir / output_name)

    # Generate address map JSON if SYM file exists and version is set
    sym_path = target_dir / "FUZZY.SYM"
    if sym_path.exists() and target.version:
        gen_script = TOOLS_DIR / "gen_addrmap.py"
        if gen_script.exists():
            json_path = target_dir / "addrmap.json"
            subprocess.run(
                [sys.executable, str(gen_script), str(sym_path),
                 "-v", target.version, "-o", str(json_path)],
                check=True,
            )

    if not keep_work:
        shutil.rmtree(work_dir)


def ensure_exists(path: Path, description: str) -> None:
    if not path.exists():
        raise SystemExit(f"{description} was not found: {path}")


def prepare_deploy_file(item: dict[str, object], staging_dir: Path) -> Path:
    file_path = Path(item["path"])
    ensure_exists(file_path, "Deploy input")

    image_name = str(item["image_name"])
    if file_path.name == image_name:
        return file_path

    staged_path = staging_dir / image_name
    shutil.copy2(file_path, staged_path)
    return staged_path


def run_command(command: list[str], check: bool = True) -> None:
    print(f"[run] {' '.join(command)}")
    subprocess.run(command, check=check)


def deploy_lsx(ndc: str) -> None:
    config = DEPLOY_TARGETS["lsx"]
    clean_image = DISK_CLEAN_DIR / config["clean_image"]
    work_image = DISK_WORK_DIR / config["work_image"]

    ensure_exists(clean_image, "Clean LSX disk image")
    DISK_WORK_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(clean_image, work_image)
    print(f"[deploy] lsx: copied {clean_image.name} -> {work_image.name}")

    with tempfile.TemporaryDirectory(prefix="fuzzybasic-lsx-", dir=DISK_WORK_DIR) as tmp_dir:
        staging_dir = Path(tmp_dir)
        for item in config["items"]:
            image_name = str(item["image_name"])
            file_path = prepare_deploy_file(item, staging_dir)
            run_command([ndc, "D", str(work_image), "0", image_name], check=False)
            run_command([ndc, "PA", str(work_image), "0", str(file_path)])


def run_hudisk(hudisk: str, args: list[str]) -> None:
    if platform.system() == "Windows":
        command = [hudisk, *args]
    else:
        mono = shutil.which("mono")
        if not mono:
            raise SystemExit("mono was not found. Install mono or run deploy on Windows.")
        command = [mono, hudisk, *args]
    run_command(command)


def deploy_sos(hudisk: str) -> None:
    config = DEPLOY_TARGETS["sos"]
    clean_image = DISK_CLEAN_DIR / config["clean_image"]
    work_image = DISK_WORK_DIR / config["work_image"]

    ensure_exists(clean_image, "Clean S-OS disk image")
    DISK_WORK_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(clean_image, work_image)
    print(f"[deploy] sos: copied {clean_image.name} -> {work_image.name}")

    with tempfile.TemporaryDirectory(prefix="fuzzybasic-sos-", dir=DISK_WORK_DIR) as tmp_dir:
        staging_dir = Path(tmp_dir)
        for item in config["items"]:
            image_name = str(item["image_name"])
            file_path = prepare_deploy_file(item, staging_dir)
            run_hudisk(hudisk, [str(work_image), "-d", image_name])

            add_args = [str(work_image), "-a", str(file_path)]
            if file_path.suffix.upper() == ".BAS":
                add_args.append("--basic")
            load_address = item.get("load_address")
            exec_address = item.get("exec_address")
            if load_address:
                add_args.extend(["-r", load_address])
            if exec_address:
                add_args.extend(["-g", exec_address])
            run_hudisk(hudisk, add_args)


def package_zip(target_name: str) -> None:
    config = DEPLOY_TARGETS[target_name]
    zip_name = config.get("zip_name")
    if not zip_name:
        return

    d88_name = config["d88_name"]
    work_image = DISK_WORK_DIR / config["work_image"]
    dist_files = config.get("dist_files", ())

    ensure_exists(work_image, "Deployed disk image")
    for dist_file in dist_files:
        ensure_exists(dist_file, "Distribution file")

    DIST_DIR.mkdir(parents=True, exist_ok=True)
    zip_path = DIST_DIR / zip_name

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write(work_image, d88_name)
        for dist_file in dist_files:
            zf.write(dist_file, dist_file.name)

    print(f"[package] {zip_path}")


def deploy_targets(selected: list[str], ndc: str | None, hudisk: str | None) -> None:
    targets = expand_targets(selected, DEFAULT_DEPLOY_TARGETS)
    selected_names = {target.name for target in targets}

    if "lsx" in selected_names:
        deploy_lsx(resolve_ndc(ndc))
        package_zip("lsx")
    if "sos" in selected_names:
        deploy_sos(resolve_hudisk(hudisk))
        package_zip("sos")


def main() -> int:
    args = parse_args()
    if args.command == "build":
        assembler = resolve_assembler(args.assembler)
        targets = expand_targets(args.targets, DEFAULT_BUILD_TARGETS)

        extra_defines = []
        if args.autorun:
            extra_defines.append("ENABLE_AUTORUN=1")

        OUT_DIR.mkdir(exist_ok=True)
        for target in targets:
            build_target(target, assembler, args.keep_work, extra_defines)

        print("[done] Outputs are under out/<target>/")
    else:
        deploy_targets(args.targets, args.ndc, args.hudisk)
        print("[done] Zip archives are under dist/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
