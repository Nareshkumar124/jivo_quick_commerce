#!/usr/bin/env python3
"""Fail if a 64-bit native library in an Android AAB or APK is not 16 KB page aligned.

Usage (from anywhere; standard library only, Python 3.9+):

    python3 infra/scripts/check_16k_alignment.py app-prod-release.aab [more.aab|.apk ...]
    python3 infra/scripts/check_16k_alignment.py --help

Google Play requires apps targeting Android 15+ to support 16 KB memory pages
(docs/deployment.md §12.3b). For every ``lib/<abi>/*.so`` in the archive this reads the
ELF program headers and checks that each ``PT_LOAD`` segment has ``p_align >= 0x4000``.
The rule applies to 64-bit ABIs (``arm64-v8a``, ``x86_64``); 32-bit libraries are listed
for information only. Zip-entry alignment of uncompressed libraries in an APK is a separate
check: ``zipalign -c -P 16 -v 4 <file>.apk``.

Exit code: 0 when every 64-bit library is aligned, 1 otherwise, 2 on bad usage.
"""

from __future__ import annotations

import struct
import sys
import zipfile

PT_LOAD = 1
MIN_ALIGN = 0x4000


def out(text: str) -> None:
    sys.stdout.write(text + "\n")


def load_aligns(data: bytes) -> tuple[bool, list[int]]:
    """Return (is_64_bit, p_align of every PT_LOAD segment) for an ELF image."""
    is64 = data[4] == 2
    end = "<" if data[5] == 1 else ">"
    if is64:
        (phoff,) = struct.unpack_from(end + "Q", data, 0x20)
        phentsize, phnum = struct.unpack_from(end + "HH", data, 0x36)
    else:
        (phoff,) = struct.unpack_from(end + "I", data, 0x1C)
        phentsize, phnum = struct.unpack_from(end + "HH", data, 0x2A)
    aligns = []
    for i in range(phnum):
        off = phoff + i * phentsize
        (ptype,) = struct.unpack_from(end + "I", data, off)
        if ptype == PT_LOAD:
            fmt, at = ("Q", 0x30) if is64 else ("I", 0x1C)
            aligns.append(struct.unpack_from(end + fmt, data, off + at)[0])
    return is64, aligns


def check(path: str) -> int:
    bad = total = 0
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            if not info.filename.endswith(".so"):
                continue
            data = archive.read(info)
            if data[:4] != b"\x7fELF":
                continue
            is64, aligns = load_aligns(data)
            low = min(aligns) if aligns else 0
            ok = not is64 or low >= MIN_ALIGN
            total += 1
            bad += not ok
            note = "" if is64 else " (32-bit, not required)"
            out(f"{'OK ' if ok else 'BAD'} min_align=0x{low:x} {info.filename}{note}")
    out(f"{path}: {total} libraries, {bad} 64-bit not 16 KB aligned")
    return bad


def main(argv: list[str]) -> int:
    if not argv or argv[0] in {"-h", "--help"}:
        out(__doc__ or "")
        return 0 if argv else 2
    return 1 if sum(check(p) for p in argv) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
