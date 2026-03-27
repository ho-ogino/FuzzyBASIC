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
    "user_hooks": {
        "USR_A": "SMTBL",
        "USR_B": "SMTBL",
        "USR_C": "SMTBL",
        "USR_D": "SMTBL",
        "USR_E": "SMTBL",
        "USR_F": "SMTBL",
        "USR_G": "SMTBL",
        "USR_H": "SMTBL",
        "FN_A": "FUNCTBL",
        "FN_B": "FUNCTBL",
        "FN_C": "FUNCTBL",
        "FN_D": "FUNCTBL",
        "FN_E": "FUNCTBL",
        "FN_F": "FUNCTBL",
        "FN_G": "FUNCTBL",
        "FN_H": "FUNCTBL",
        "PR_A": "PRTTBL",
        "PR_B": "PRTTBL",
    },
}

# USR^A-H, FN^A-H, PR^A-B are computed from table base + index.
# These are not direct SYM lookups but calculated addresses.
# Index = (no+N) - $80 = N - 1. Token no+N dispatches to table[N-1].
USER_HOOKS = {
    "USR_A": ("SMTBL", 92), "USR_B": ("SMTBL", 93),
    "USR_C": ("SMTBL", 94), "USR_D": ("SMTBL", 95),
    "USR_E": ("SMTBL", 96), "USR_F": ("SMTBL", 97),
    "USR_G": ("SMTBL", 98), "USR_H": ("SMTBL", 99),
    "FN_A": ("FUNCTBL", 58), "FN_B": ("FUNCTBL", 59),
    "FN_C": ("FUNCTBL", 60), "FN_D": ("FUNCTBL", 61),
    "FN_E": ("FUNCTBL", 62), "FN_F": ("FUNCTBL", 63),
    "FN_G": ("FUNCTBL", 64), "FN_H": ("FUNCTBL", 65),
    "PR_A": ("PRTTBL", 13), "PR_B": ("PRTTBL", 14),
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


def build_addrmap(sym: dict[str, int], version: str, sym_path: Path,
                  allow_missing: bool = False) -> dict:
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
        if category == "user_hooks":
            continue  # Handled separately below
        cat_data = {}
        for json_key, sym_name in entries.items():
            addr = _resolve_symbol(sym, sym_name)
            if addr is None:
                missing.append(f"{category}.{json_key} (sym: {sym_name})")
                if allow_missing:
                    cat_data[json_key] = None
            else:
                cat_data[json_key] = f"0x{addr:04X}"
        result[category] = cat_data

    # User hooks: computed from table base + index * 2
    hooks_data = {}
    for hook_name, (table_name, index) in USER_HOOKS.items():
        base = _resolve_symbol(sym, table_name)
        if base is None:
            missing.append(f"user_hooks.{hook_name} (table: {table_name})")
        else:
            hooks_data[hook_name] = f"0x{base + index * 2:04X}"
    result["user_hooks"] = hooks_data

    if missing and not allow_missing:
        raise SystemExit(
            f"[addrmap] ERROR: {len(missing)} required symbol(s) not found in SYM:\n"
            + "\n".join(f"  - {m}" for m in missing)
        )
    if missing and allow_missing:
        print(f"[addrmap] WARNING: {len(missing)} symbol(s) not found (set to null)",
              file=sys.stderr)

    return result


def main():
    p = argparse.ArgumentParser(description="Generate address map JSON from SYM file")
    p.add_argument("sym", help="Path to FUZZY.SYM")
    p.add_argument("-v", "--version", default="unknown",
                   help="FuzzyBASIC version (e.g. 1.2L)")
    p.add_argument("-o", "--output", help="Output JSON file (default: stdout)")
    p.add_argument("--merge", help="Merge into existing JSON file (multi-version)")
    p.add_argument("--allow-missing", action="store_true",
                   help="Allow missing symbols (set to null instead of error)")
    args = p.parse_args()

    sym_path = Path(args.sym)
    sym = parse_sym(sym_path)
    addrmap = build_addrmap(sym, args.version, sym_path,
                            allow_missing=args.allow_missing)

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
