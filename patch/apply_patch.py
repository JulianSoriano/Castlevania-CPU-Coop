#!/usr/bin/env python3
"""Applies Castlevania_CPU_Coop_v8.ips to a regular Castlevania (USA) Rev 1 ROM.
Usage:  python3 apply_patch.py "Castlevania (USA) (Rev 1).nes"
Needs only Python 3. Writes "Castlevania_CPU_Coop_v8.nes" next to the patch."""
import sys, hashlib, os
SRC_MD5 = "52eb3f7e2c5fc765aa71f21c85f0770e"   # Castlevania (USA) Rev 1, 131,088 bytes
OUT_MD5 = "10fba4c7e1e2fadd85e35c298c052228"
here = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) != 2:
    sys.exit(__doc__)
rom = bytearray(open(sys.argv[1], "rb").read())
if hashlib.md5(rom).hexdigest() != SRC_MD5:
    sys.exit("This is not the right ROM (need Castlevania USA Rev 1, 131,088 bytes, MD5 %s).\n"
             "Yours is %d bytes, MD5 %s." % (SRC_MD5, len(rom), hashlib.md5(rom).hexdigest()))
p = open(os.path.join(here, "Castlevania_CPU_Coop_v8.ips"), "rb").read()
assert p[:5] == b"PATCH"
k = 5
while p[k:k+3] != b"EOF":
    off = int.from_bytes(p[k:k+3], "big"); n = int.from_bytes(p[k+3:k+5], "big"); k += 5
    if off + n > len(rom): rom.extend(bytes(off + n - len(rom)))
    rom[off:off+n] = p[k:k+n]; k += n
if hashlib.md5(rom).hexdigest() != OUT_MD5:
    sys.exit("Patching went wrong (checksum mismatch).")
out = os.path.join(here, "Castlevania_CPU_Coop_v8.nes")
open(out, "wb").write(rom); print("Done:", out)
