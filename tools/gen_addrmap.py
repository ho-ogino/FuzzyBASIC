#!/usr/bin/env python3
"""
Generate address map JSON from FUZZY.SYM for Web application integration.

Usage:
    python3 tools/gen_addrmap.py out/lsx/FUZZY.SYM -v 1.2L -o out/lsx/addrmap.json

The output JSON is keyed by version and includes a build fingerprint
(git commit + timestamp) so that the same version string from different
builds can be distinguished.
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# ──────────────────────────────────────────────
# Symbols to export.  Every symbol listed here is REQUIRED;
# a missing symbol is a build error (not silently null).
# ──────────────────────────────────────────────
SYMBOLS = {
    "memory": {
        "TEXTAREA": "TEXTAREA",
        "TEXTST": "TEXTST",
        "TEXTED": "TEXTED",
        "VARVAL": "VARVAL",
        "VARSP": "VARSP",
        "MEMAX": "MEMAX",
    },
    "system": {
        "BRK": "BRK",
        "NOWADR": "NOWADR",
        "STOPF": "STOPF",
        "SYSSTK": "SYSSTK",
        "STKTP": "STKTP",
        "VSTKST": "VSTKST",
        "VSTKED": "VSTKED",
        "PROCVAR": "PROCVAR",
    },
    "sound": {
        "SOUNDTOP": "SOUNDTOP",
        "SND_Init": "SND_Init",
        "SND_BGMPlay": "SND_BGMPlay",
        "SND_BGMStop": "SND_BGMStop",
        "SND_BGMPause": "SND_BGMPause",
        "SND_BGMResume": "SND_BGMResume",
        "SND_SFXInit": "SND_SFXInit",
        "SND_SFXPlay": "SND_SFXPlay",
        "SND_SFXStop": "SND_SFXStop",
        "SND_PSG_PROC": "SND_PSG_PROC",
        "SND_PSG_END": "SND_PSG_END",
        "SND_CTC_PORT": "SND_CTC_PORT",
        "SND_CTCVEC": "SND_CTCVEC",
        "SNDFLG": "SOS.SNDFLG",
        "VSYNC_PREV": "SOS.VSYNC_PREV",
        "SNDCTC": "SOS.SNDCTC",
    },
    "graphics": {
        "MAGICTOP": "MAGICTOP",
    },
    "interpreter": {
        "SOUND_": "SOUND_",
        "SNDPOLL": "SNDPOLL",
        "LINED": "LINED",
        "NXLIN": "NXLIN",
        "JIKKOU": "JIKKOU",
    },
}


def parse_sym(sym_path: Path) -> dict[str, int]:
    """Parse ailz80asm SYM file into {name: address} dict.

    Prioritizes NAME_SPACE_DEFAULT entries over other namespaces.
    """
    symbols = {}
    ns_symbols = {}
    for line in sym_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith(";") or line.startswith("["):
            continue
        m = re.match(r"([0-9A-Fa-f]+)\s+(\S+)", line)
        if m:
            addr = int(m.group(1), 16)
            name = m.group(2)
            if name.startswith("NAME_SPACE_DEFAULT."):
                short = name[len("NAME_SPACE_DEFAULT."):]
                ns_symbols[short] = addr
            symbols[name] = addr
    for short, addr in ns_symbols.items():
        symbols[short] = addr
    return symbols


def _resolve_symbol(sym: dict[str, int], name: str) -> int | None:
    """Resolve a symbol name, trying various namespace forms."""
    if name in sym:
        return sym[name]
    if "." in name:
        short = name.split(".")[-1]
        if short in sym:
            return sym[short]
    suffix = f".{name}"
    for full_name, addr in sym.items():
        if full_name.endswith(suffix):
            return addr
    return None


def _git_commit() -> str:
    """Return short git commit hash, or 'unknown'."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, timeout=5,
        )
        return result.stdout.strip() if result.returncode == 0 else "unknown"
    except Exception:
        return "unknown"


def _sym_sha256(sym_path: Path) -> str:
    """Return SHA-256 of the SYM file (first 12 hex chars)."""
    h = hashlib.sha256(sym_path.read_bytes()).hexdigest()
    return h[:12]


def build_addrmap(sym: dict[str, int], version: str, sym_path: Path) -> dict:
    missing = []

    result = {
        "version": version,
        "build": {
            "git_commit": _git_commit(),
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "sym_sha256": _sym_sha256(sym_path),
            "target": "lsx",
        },
    }

    for category, entries in SYMBOLS.items():
        cat_data = {}
        for json_key, sym_name in entries.items():
            addr = _resolve_symbol(sym, sym_name)
            if addr is None:
                missing.append(f"{category}.{json_key} (sym: {sym_name})")
            else:
                cat_data[json_key] = f"0x{addr:04X}"
        result[category] = cat_data

    if missing:
        raise SystemExit(
            f"[addrmap] ERROR: {len(missing)} required symbol(s) not found in SYM:\n"
            + "\n".join(f"  - {m}" for m in missing)
        )

    return result


def main():
    p = argparse.ArgumentParser(description="Generate address map JSON from SYM file")
    p.add_argument("sym", help="Path to FUZZY.SYM")
    p.add_argument("-v", "--version", default="unknown",
                   help="FuzzyBASIC version (e.g. 1.2L)")
    p.add_argument("-o", "--output", help="Output JSON file (default: stdout)")
    p.add_argument("--merge", help="Merge into existing JSON file (multi-version)")
    args = p.parse_args()

    sym_path = Path(args.sym)
    sym = parse_sym(sym_path)
    addrmap = build_addrmap(sym, args.version, sym_path)

    if args.merge:
        merge_path = Path(args.merge)
        if merge_path.exists():
            existing = json.loads(merge_path.read_text(encoding="utf-8"))
        else:
            existing = {}
        existing[args.version] = addrmap
        json_text = json.dumps(existing, indent=2, ensure_ascii=False)
        merge_path.write_text(json_text + "\n", encoding="utf-8")
        print(f"[addrmap] Merged version {args.version} into {args.merge}",
              file=sys.stderr)
    else:
        json_text = json.dumps(addrmap, indent=2, ensure_ascii=False)
        if args.output:
            Path(args.output).write_text(json_text + "\n", encoding="utf-8")
            print(f"[addrmap] Written to {args.output}", file=sys.stderr)
        else:
            print(json_text)


if __name__ == "__main__":
    main()
