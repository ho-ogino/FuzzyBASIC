#!/usr/bin/env python3
"""
Generate relocatable binary (.REL) files from Z80 assembly sources.

Reads reloc_config.json to determine which binaries to process, builds each
at default and shifted (+$0100) ORG addresses, diffs to find fixup locations,
and produces REL files with multi-group patch tables.

This is a page-boundary relocator: target addresses must be xx00h aligned.

Usage:
    python3 tools/mkreloc.py                        # Process all binaries
    python3 tools/mkreloc.py --binary MAGIC          # Process specific binary
    python3 tools/mkreloc.py --manifest-only         # Regenerate manifest only

REL format (v2, multi-group):
    [2 bytes]     table_size (offset to binary body)
    [2 bytes]     binary_size
    [1 byte]      group_count
    --- per group ---
    [16 bytes]    name (null-padded ASCII, max 15 chars)
    [2 bytes]     default_address (xx00h)
    [2 bytes]     fixup_count (N)
    [N * 2 bytes] fixup offsets (high-byte patch positions)
    --- end groups ---
    [binary body]
"""

import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


SHIFT_AMOUNT = 0x0100


# ──────────────────────────────────────────────
# Value formatting for different assemblers
# ──────────────────────────────────────────────

def format_value(addr: int, fmt: str) -> str:
    """Format an address integer as an assembler-specific string."""
    if fmt == "ailz80_dollar":
        return f"${addr:04X}"
    elif fmt == "ailz80_h":
        return f"0{addr:04X}H"
    elif fmt == "rasm_hash":
        return f"#{addr:04x}"
    elif fmt == "rasm_0x":
        return f"0x{addr:04x}"
    else:
        raise ValueError(f"Unknown value_format: {fmt}")


# ──────────────────────────────────────────────
# Source patching
# ──────────────────────────────────────────────

def patch_source(source_text: str, pattern_template: str, value_format: str,
                 old_addr: int, new_addr: int) -> str:
    """Replace an address value in source text using a regex pattern.

    The pattern_template contains {value} which is replaced with a regex
    matching the old address in the appropriate format.
    """
    old_str = format_value(old_addr, value_format)
    new_str = format_value(new_addr, value_format)

    # Escape the old value for regex ($ needs escaping)
    old_escaped = re.escape(old_str)
    # Build the full pattern with the concrete old value
    full_pattern = pattern_template.replace("{value}", old_escaped)

    matches = list(re.finditer(full_pattern, source_text))
    if len(matches) == 0:
        raise RuntimeError(
            f"Pattern '{full_pattern}' matched 0 times in source "
            f"(looking for {old_str})"
        )
    if len(matches) > 1:
        raise RuntimeError(
            f"Pattern '{full_pattern}' matched {len(matches)} times in source "
            f"(expected exactly 1)"
        )

    # Replace the old value with the new value within the matched region
    match = matches[0]
    matched_text = match.group(0)
    replaced_text = matched_text.replace(old_str, new_str)
    return source_text[:match.start()] + replaced_text + source_text[match.end():]


# ──────────────────────────────────────────────
# Assembler invocation
# ──────────────────────────────────────────────

def find_assembler(name: str) -> str:
    """Find assembler executable."""
    if name == "ailz80asm":
        for candidate in [os.environ.get("AILZ80ASM", ""), "/usr/local/bin/AILZ80ASM",
                          "AILZ80ASM", "ailz80asm"]:
            if candidate and shutil.which(candidate):
                return candidate
        raise FileNotFoundError("ailz80asm not found")
    elif name == "rasm":
        path = shutil.which("rasm")
        if path:
            return path
        raise FileNotFoundError("rasm not found")
    raise ValueError(f"Unknown assembler: {name}")


def build_ailz80asm(assembler: str, source: Path, build_args: list,
                    output: Path) -> None:
    """Build with ailz80asm."""
    cmd = [assembler, str(source), *build_args, "-bin"]
    subprocess.run(cmd, cwd=source.parent, check=True,
                   capture_output=True, text=True)
    # ailz80asm outputs SOURCE_NAME.BIN in the source directory
    default_out = source.with_suffix(".BIN")
    if default_out != output:
        shutil.copy2(default_out, output)
        default_out.unlink()
    # Clean up LST/SYM if generated
    for ext in [".LST", ".SYM"]:
        cleanup = source.with_suffix(ext)
        if cleanup.exists():
            cleanup.unlink()


def build_rasm(assembler: str, source: Path, build_args: list,
               output: Path, extra_defines: dict | None = None) -> None:
    """Build with RASM."""
    stem = output.with_suffix("")
    cmd = [assembler, str(source), "-o", str(stem), "-s", "-eo", *build_args]
    if extra_defines:
        for name, value in extra_defines.items():
            cmd.append(f"-D{name}={value}")
    subprocess.run(cmd, cwd=source.parent, check=True,
                   capture_output=True, text=True)
    # RASM outputs stem.bin
    rasm_out = Path(str(stem) + ".bin")
    if rasm_out != output:
        shutil.copy2(rasm_out, output)
        rasm_out.unlink()
    # Clean up .sym
    sym_out = Path(str(stem) + ".sym")
    if sym_out.exists():
        sym_out.unlink()


def build_binary(assembler_name: str, source: Path, build_args: list,
                 output: Path, extra_defines: dict | None = None) -> None:
    """Build a binary with the appropriate assembler."""
    asm = find_assembler(assembler_name)
    if assembler_name == "ailz80asm":
        build_ailz80asm(asm, source, build_args, output)
    elif assembler_name == "rasm":
        build_rasm(asm, source, build_args, output, extra_defines)


# ──────────────────────────────────────────────
# Fixup detection
# ──────────────────────────────────────────────

def detect_fixups(base_bin: bytes, shifted_bin: bytes) -> list[int]:
    """Compare two binaries (default vs +$0100) and find high-byte fixup offsets."""
    if len(base_bin) != len(shifted_bin):
        raise RuntimeError(
            f"Binary size mismatch: {len(base_bin)} vs {len(shifted_bin)}"
        )

    fixups = []
    errors = []
    for i in range(len(base_bin)):
        diff = (shifted_bin[i] - base_bin[i]) & 0xFF
        if diff == 0:
            continue
        if diff == 1:
            fixups.append(i)
        else:
            errors.append((i, base_bin[i], shifted_bin[i], diff))

    if errors:
        msg = f"{len(errors)} unexpected difference(s):\n"
        for offset, b0, b1, diff in errors[:10]:
            msg += f"  ${offset:04X}: ${b0:02X} -> ${b1:02X} (diff={diff})\n"
        raise RuntimeError(msg)

    return fixups


# ──────────────────────────────────────────────
# REL file generation
# ──────────────────────────────────────────────

def build_rel(binary_data: bytes, groups: list[dict]) -> bytes:
    """Build a REL file from binary data and group fixup info.

    groups: list of {"name": str, "default": int, "fixups": list[int]}
    """
    # Validate group names
    for g in groups:
        name = g["name"]
        if len(name) > 15:
            raise ValueError(f"Group name '{name}' exceeds 15 characters")
        if not all(32 <= ord(c) < 127 for c in name):
            raise ValueError(f"Group name '{name}' contains non-ASCII characters")

    # Build group table
    group_data = b""
    for g in groups:
        name_bytes = g["name"].encode("ascii").ljust(16, b"\x00")[:16]
        default = g["default"]
        fixups = g["fixups"]
        group_data += name_bytes
        group_data += struct.pack("<HH", default, len(fixups))
        for offset in fixups:
            group_data += struct.pack("<H", offset)

    binary_size = len(binary_data)
    group_count = len(groups)
    # header: table_size(2) + binary_size(2) + group_count(1) = 5
    table_size = 5 + len(group_data)

    header = struct.pack("<HHB", table_size, binary_size, group_count)
    return header + group_data + binary_data


# ──────────────────────────────────────────────
# Main processing
# ──────────────────────────────────────────────

def process_binary(name: str, binary_cfg: dict, symbols: dict,
                   config_dir: Path, output_dir: Path, verbose: bool) -> dict:
    """Process one binary entry from reloc_config.json.

    Returns manifest entry dict.
    """
    source = (config_dir / binary_cfg["source"]).resolve()
    if not source.exists():
        raise FileNotFoundError(f"Source not found: {source}")

    assembler = binary_cfg["assembler"]
    build_args = binary_cfg.get("build_args", [])
    groups_cfg = binary_cfg["groups"]

    print(f"[mkreloc] Processing {name} ({source.name})", file=sys.stderr)

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)

        # Step 1: Build at default values
        base_output = tmpdir / f"{name}_base.bin"

        if assembler == "rasm":
            build_binary(assembler, source, build_args, base_output)
        else:
            # ailz80asm: use original source directly
            # Copy source to temp with a clean name (avoid conflicts)
            tmp_src = source.parent / f"_mkreloc_tmp_{source.name}"
            shutil.copy2(source, tmp_src)
            try:
                build_binary(assembler, tmp_src, build_args, base_output)
            finally:
                tmp_src.unlink(missing_ok=True)

        base_bin = base_output.read_bytes()

        # Step 2: For each group, build shifted and detect fixups
        group_results = []
        for group_name, group_cfg in groups_cfg.items():
            symbol_name = group_cfg["symbol"]
            default_addr = int(symbols[symbol_name]["default"], 16)
            shifted_addr = default_addr + SHIFT_AMOUNT

            if verbose:
                print(f"  Group '{group_name}': {symbol_name} "
                      f"${default_addr:04X} -> ${shifted_addr:04X}",
                      file=sys.stderr)

            shifted_output = tmpdir / f"{name}_{group_name}_shifted.bin"

            if "define" in group_cfg:
                # RASM: use -D option
                defines = {group_cfg["define"]: f"0x{shifted_addr:04x}"}
                build_binary(assembler, source, build_args,
                             shifted_output, extra_defines=defines)
            elif "source_pattern" in group_cfg:
                # ailz80asm: patch source
                src_text = source.read_text(encoding="utf-8", errors="replace")
                patched = patch_source(
                    src_text,
                    group_cfg["source_pattern"],
                    group_cfg["value_format"],
                    default_addr,
                    shifted_addr,
                )
                tmp_src = source.parent / f"_mkreloc_tmp_{source.name}"
                tmp_src.write_text(patched, encoding="utf-8")
                try:
                    build_binary(assembler, tmp_src, build_args, shifted_output)
                finally:
                    tmp_src.unlink(missing_ok=True)
            else:
                raise ValueError(
                    f"Group '{group_name}' needs either 'define' or "
                    f"'source_pattern'"
                )

            shifted_bin = shifted_output.read_bytes()
            fixups = detect_fixups(base_bin, shifted_bin)

            if verbose:
                print(f"    Found {len(fixups)} fixups", file=sys.stderr)

            group_results.append({
                "name": group_name,
                "default": default_addr,
                "fixups": fixups,
            })

        # Step 3: Build REL file
        rel_data = build_rel(base_bin, group_results)
        rel_filename = binary_cfg.get("rel_file", f"{name}.REL")
        rel_path = output_dir / rel_filename
        rel_path.write_bytes(rel_data)

        print(f"  -> {rel_path.name}: {len(rel_data)} bytes "
              f"(binary={len(base_bin)}, "
              f"groups={len(group_results)})",
              file=sys.stderr)

        # Return manifest entry
        return {
            "rel_file": binary_cfg.get("rel_file", f"{name}.REL"),
            "output_file": binary_cfg.get("output_file", f"{name}.BIN"),
            "binary_size": len(base_bin),
            "rel_size": len(rel_data),
            "groups": [
                {
                    "name": g["name"],
                    "symbol": groups_cfg[g["name"]]["symbol"],
                    "default": f"0x{g['default']:04X}",
                    "fixup_count": len(g["fixups"]),
                }
                for g in group_results
            ],
        }


def main():
    p = argparse.ArgumentParser(
        description="Generate relocatable .REL files from reloc_config.json"
    )
    p.add_argument("--config", default=None,
                   help="Path to reloc_config.json (default: tools/reloc_config.json)")
    p.add_argument("--binary", default=None,
                   help="Process only this binary name")
    p.add_argument("--output-dir", default=None,
                   help="Output directory (default: out/reloc)")
    p.add_argument("--manifest-only", action="store_true",
                   help="Only regenerate manifest from existing REL files")
    p.add_argument("-v", "--verbose", action="store_true")
    args = p.parse_args()

    # Find config
    if args.config:
        config_path = Path(args.config)
    else:
        # Default: tools/reloc_config.json relative to this script
        config_path = Path(__file__).parent / "reloc_config.json"
    if not config_path.exists():
        print(f"Error: Config not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    config = json.loads(config_path.read_text(encoding="utf-8"))
    config_dir = config_path.parent
    symbols = config["symbols"]
    binaries = config["binaries"]

    # Output directory
    if args.output_dir:
        output_dir = Path(args.output_dir)
    else:
        output_dir = config_dir.parent / "out" / "reloc"
    output_dir.mkdir(parents=True, exist_ok=True)

    # Filter binaries
    if args.binary:
        if args.binary not in binaries:
            print(f"Error: Binary '{args.binary}' not in config", file=sys.stderr)
            sys.exit(1)
        binaries = {args.binary: binaries[args.binary]}

    # Manifest-only mode: regenerate from existing REL files
    if args.manifest_only:
        manifest_entries = {}
        for name, binary_cfg in binaries.items():
            rel_filename = binary_cfg.get("rel_file", f"{name}.REL")
            rel_path = output_dir / rel_filename
            if not rel_path.exists():
                print(f"Error: REL file not found: {rel_path}", file=sys.stderr)
                sys.exit(1)
            rel_data = rel_path.read_bytes()
            table_size, binary_size, group_count = struct.unpack_from("<HHB", rel_data)
            groups = []
            offset = 5
            groups_cfg = binary_cfg["groups"]
            group_names = list(groups_cfg.keys())
            for i in range(group_count):
                gname = rel_data[offset:offset+16].rstrip(b"\x00").decode("ascii")
                default_addr, fixup_count = struct.unpack_from("<HH", rel_data, offset+16)
                groups.append({
                    "name": gname,
                    "symbol": groups_cfg[gname]["symbol"] if gname in groups_cfg else gname,
                    "default": f"0x{default_addr:04X}",
                    "fixup_count": fixup_count,
                })
                offset += 16 + 2 + 2 + fixup_count * 2
            manifest_entries[rel_filename] = {
                "rel_file": rel_filename,
                "output_file": binary_cfg.get("output_file", f"{name}.BIN"),
                "binary_size": binary_size,
                "rel_size": len(rel_data),
                "groups": groups,
            }
        # Jump to manifest/webapp writing
        _write_outputs(manifest_entries, symbols, output_dir)
        return

    # Process each binary
    manifest_entries = {}
    for name, binary_cfg in binaries.items():
        try:
            entry = process_binary(
                name, binary_cfg, symbols, config_dir, output_dir, args.verbose
            )
            rel_key = binary_cfg.get("rel_file", f"{name}.REL")
            manifest_entries[rel_key] = entry
        except Exception as e:
            print(f"Error processing {name}: {e}", file=sys.stderr)
            sys.exit(1)

    _write_outputs(manifest_entries, symbols, output_dir)


def _write_outputs(manifest_entries: dict, symbols: dict, output_dir: Path) -> None:
    """Write reloc_webapp.json."""
    webapp = {
        "symbols": {
            name: {
                "default": info["default"],
                "constraint": "xx00h",
                "label": info.get("label", {"en": name}),
            }
            for name, info in symbols.items()
        },
        "binaries": {
            key: {
                "rel_file": entry["rel_file"],
                "output_file": entry["output_file"],
                "binary_size": entry["binary_size"],
                "rel_size": entry["rel_size"],
                "groups": [
                    {
                        "name": g["name"],
                        "symbol": g["symbol"],
                        "default": g["default"],
                        "fixup_count": g["fixup_count"],
                    }
                    for g in entry["groups"]
                ],
            }
            for key, entry in manifest_entries.items()
        },
    }

    webapp_path = output_dir / "reloc_webapp.json"
    webapp_path.write_text(
        json.dumps(webapp, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"[mkreloc] Output: {webapp_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
