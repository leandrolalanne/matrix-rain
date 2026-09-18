#!/usr/bin/env python3
"""Derive a terminal-safe font from Matrix-Code.ttf.

A terminal cannot be told to change its font from the inside, so the only way
the film's glyphs appear in the window you typed in is for that terminal to
already resolve them. Adding Matrix-Code itself to the font chain would work,
but it maps real codepoints -- digits, ':', '|' -- and would then supply them
to every window of that terminal forever.

This builds a copy whose glyphs live at 0x100000 + their original codepoint,
in plane 16, the Supplementary Private Use Area-B. Nothing emits those: Nerd
Fonts stop at plane 15, and no text a person reads is there. So the derived
font can sit in a font chain permanently and can never be reached by anything
but the renderer that asks for it on purpose.

Only the cmap and name tables change. The outlines are untouched.

    tools/make-terminal-font.py assets/Matrix-Code.ttf assets/Matrix-Code-Terminal.ttf

Pure stdlib, like the rest of this project.
"""

import struct
import sys
from pathlib import Path

PUA_BASE = 0x100000  # plane 16; 0x100000 + 0xFFFD still fits below 0x10FFFE


# --- reading ----------------------------------------------------------------

def tables(data):
    """{tag: (offset, length)} from the table directory."""
    count = struct.unpack(">H", data[4:6])[0]
    out = {}
    for i in range(count):
        o = 12 + 16 * i
        tag = data[o:o + 4].decode("latin1")
        _, off, length = struct.unpack(">III", data[o + 4:o + 16])
        out[tag] = (off, length)
    return out


def read_cmap(data, tabs):
    """{codepoint: glyph id} from the best Unicode subtable."""
    base = tabs["cmap"][0]
    count = struct.unpack(">H", data[base + 2:base + 4])[0]
    chosen = None
    for i in range(count):
        p = base + 4 + 8 * i
        pid, eid, off = struct.unpack(">HHI", data[p:p + 8])
        if (pid, eid) in ((3, 10), (0, 4), (0, 6)):
            chosen = base + off
            break
        if (pid, eid) in ((3, 1), (0, 3)) and chosen is None:
            chosen = base + off
    if chosen is None:
        raise SystemExit("no Unicode cmap subtable")

    fmt = struct.unpack(">H", data[chosen:chosen + 2])[0]
    cmap = {}
    if fmt == 4:
        seg2 = struct.unpack(">H", data[chosen + 6:chosen + 8])[0]
        segs = seg2 // 2
        ends = chosen + 14
        starts = ends + seg2 + 2
        deltas = starts + seg2
        ranges = deltas + seg2
        for s in range(segs):
            end = struct.unpack(">H", data[ends + 2 * s:ends + 2 * s + 2])[0]
            start = struct.unpack(">H", data[starts + 2 * s:starts + 2 * s + 2])[0]
            delta = struct.unpack(">h", data[deltas + 2 * s:deltas + 2 * s + 2])[0]
            ro = struct.unpack(">H", data[ranges + 2 * s:ranges + 2 * s + 2])[0]
            if start == 0xFFFF:
                continue
            for cp in range(start, end + 1):
                if ro == 0:
                    gid = (cp + delta) & 0xFFFF
                else:
                    gp = ranges + 2 * s + ro + 2 * (cp - start)
                    gid = struct.unpack(">H", data[gp:gp + 2])[0]
                    if gid:
                        gid = (gid + delta) & 0xFFFF
                if gid:
                    cmap[cp] = gid
    elif fmt == 12:
        groups = struct.unpack(">I", data[chosen + 12:chosen + 16])[0]
        for g in range(groups):
            p = chosen + 16 + 12 * g
            start, end, gid = struct.unpack(">III", data[p:p + 12])
            for i, cp in enumerate(range(start, end + 1)):
                cmap[cp] = gid + i
    else:
        raise SystemExit(f"cmap format {fmt} not handled")
    return cmap


def read_names(data, tabs):
    """[(platform, encoding, language, nameID, text)] from the name table."""
    base, _ = tabs["name"]
    count, strings = struct.unpack(">HH", data[base + 2:base + 6])
    out = []
    for i in range(count):
        p = base + 6 + 12 * i
        pid, eid, lid, nid, length, off = struct.unpack(">HHHHHH", data[p:p + 12])
        raw = data[base + strings + off:base + strings + off + length]
        text = raw.decode("utf-16-be" if pid == 3 else "latin1", "replace")
        out.append((pid, eid, lid, nid, text))
    return out


# --- writing ----------------------------------------------------------------

def build_cmap(mapping):
    """A single format 12 subtable, platform 3 encoding 10. Plane 16 needs it:
    format 4 is capped at the BMP."""
    groups = []
    for cp in sorted(mapping):
        gid = mapping[cp]
        if groups and cp == groups[-1][1] + 1 and gid == groups[-1][2] + (groups[-1][1] - groups[-1][0]) + 1:
            groups[-1][1] = cp
        else:
            groups.append([cp, cp, gid])

    body = struct.pack(">HHIII", 12, 0, 16 + 12 * len(groups), 0, len(groups))
    for start, end, gid in groups:
        body += struct.pack(">III", start, end, gid)
    header = struct.pack(">HH", 0, 1) + struct.pack(">HHI", 3, 10, 12)
    return header + body


def build_name(records):
    """A format 0 name table. Strings are deduplicated the way most tools do."""
    blob = b""
    offsets = {}
    entries = []
    for pid, eid, lid, nid, text in sorted(records, key=lambda r: (r[0], r[1], r[2], r[3])):
        raw = text.encode("utf-16-be" if pid == 3 else "latin1", "replace")
        if raw not in offsets:
            offsets[raw] = len(blob)
            blob += raw
        entries.append(struct.pack(">HHHHHH", pid, eid, lid, nid, len(raw), offsets[raw]))
    return struct.pack(">HHH", 0, len(entries), 6 + 12 * len(entries)) + b"".join(entries) + blob


def checksum(data):
    data = data + b"\0" * (-len(data) % 4)
    return sum(struct.unpack(">%dI" % (len(data) // 4), data)) & 0xFFFFFFFF


def build_font(parts):
    """Assemble a table directory and its tables, with correct checksums."""
    tags = sorted(parts)
    n = len(tags)
    entry = max(0, n.bit_length() - 1)
    search = (1 << entry) * 16
    header = struct.pack(">IHHHH", 0x00010000, n, search, entry, n * 16 - search)

    offset = 12 + 16 * n
    directory, body = b"", b""
    for tag in tags:
        blob = parts[tag]
        directory += tag.encode("latin1") + struct.pack(">III", checksum(blob), offset, len(blob))
        padded = blob + b"\0" * (-len(blob) % 4)
        body += padded
        offset += len(padded)

    font = header + directory + body
    # head.checkSumAdjustment is computed over the finished file, with the field
    # itself zeroed -- which it already is, because we zero it before calling.
    head_off = 12 + 16 * tags.index("head")
    head_at = struct.unpack(">I", font[head_off + 8:head_off + 12])[0]
    adjustment = (0xB1B0AFBA - checksum(font)) & 0xFFFFFFFF
    return font[:head_at + 8] + struct.pack(">I", adjustment) + font[head_at + 12:]


# --- main -------------------------------------------------------------------

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    family = "Matrix-Code Terminal"
    for a in sys.argv[1:]:
        if a.startswith("--family="):
            family = a.split("=", 1)[1]
    if len(args) != 2:
        raise SystemExit(__doc__)

    src, dst = Path(args[0]).expanduser(), Path(args[1]).expanduser()
    data = src.read_bytes()
    tabs = tables(data)
    cmap = read_cmap(data, tabs)

    shifted = {PUA_BASE + cp: gid for cp, gid in cmap.items()}
    if max(shifted) > 0x10FFFD:
        raise SystemExit("shifted past the end of plane 16")

    postscript = family.replace(" ", "-")
    replace = {1: family, 3: family + "; derived for terminal use",
               4: family, 6: postscript, 16: family}
    names = []
    for pid, eid, lid, nid, text in read_names(data, tabs):
        names.append((pid, eid, lid, nid, replace.get(nid, text)))

    parts = {}
    for tag, (off, length) in tabs.items():
        parts[tag] = data[off:off + length]
    parts["cmap"] = build_cmap(shifted)
    parts["name"] = build_name(names)

    # head.checkSumAdjustment must be zero while the file checksum is taken.
    head = bytearray(parts["head"])
    head[8:12] = b"\0\0\0\0"
    parts["head"] = bytes(head)

    # OS/2 records the BMP range it covers. There is none now; the spec's value
    # for that is 0xFFFF in both fields.
    if "OS/2" in parts:
        os2 = bytearray(parts["OS/2"])
        if len(os2) >= 66:
            os2[64:68] = struct.pack(">HH", 0xFFFF, 0xFFFF)
        parts["OS/2"] = bytes(os2)

    # FFTM and GDEF describe the source's own layout; nothing here touches
    # either, so they ride along unchanged.
    dst.write_bytes(build_font(parts))
    print(f"{dst}: {len(shifted)} glyphs at U+{min(shifted):X}-U+{max(shifted):X}, family {family!r}")


if __name__ == "__main__":
    main()
